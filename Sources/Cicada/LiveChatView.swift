import SwiftUI

struct LiveChatView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var state: LiveChatState
    @State private var hovered = false

    var body: some View {
        let session = store.session(state.sessionID)
        let subdued = state.quiet && !hovered
        ZStack {
            if state.expanded {
                VStack(spacing: 0) {
                    HStack {
                        Text(verbatim: "Cicada").font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "waveform").foregroundStyle(.white.opacity(state.quiet ? 0.48 : 0.85))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 5)
                    LiveChatHistory(session: session, state: state, subdued: subdued)
                        .id(state.sessionID)
                }
            } else {
                Label(L("实时对话"), systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .background(Color(red: 0.13, green: 0.14, blue: 0.18).opacity(subdued ? 0.50 : 0.82))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.22)).allowsHitTesting(false))
        .animation(.easeOut(duration: 0.18), value: subdued)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }
}

private struct LiveChatHistory: View {
    let session: Session?
    @ObservedObject var state: LiveChatState
    let subdued: Bool
    @State private var following = true
    @State private var followQueued = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if let session {
                        ForEach(session.lines) { line in
                            row(.recorded(line, in: session))
                        }
                    }
                    ForEach(state.standalone) { row($0) }
                    ForEach(state.incoming) { row($0) }
                    if let outgoing = state.outgoing { row(outgoing) }
                    Color.clear.frame(height: 1).bottomMarker().id("chat-bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 3)
            }
            .onLegacyBottomDistance { distance in
                if UserScroll.recent { following = distance <= 5 }
                else if distance > 1 { follow(proxy) }
            }
            .onScrollEdgeChange { old, new in
                if new.height != old.height || new.container != old.container {
                    if new.distance > 1 { follow(proxy) }
                } else if new.distance <= 5 {
                    following = true
                } else if new.distance > old.distance {
                    following = false
                }
            }
            .onChange(of: session?.lines.last?.id) { _, _ in follow(proxy) }
            .onChange(of: state.standalone.count) { _, _ in follow(proxy) }
            .onAppear {
                UserScroll.install()
                follow(proxy)
            }
            .overlay(alignment: .bottomTrailing) {
                if !following {
                    Button {
                        following = true
                        follow(proxy)
                    } label: {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(7)
                            .background(Circle().fill(Color(white: 0.15)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("回到最新消息"))
                    .help(L("回到最新消息"))
                    .padding(7)
                }
            }
        }
    }

    private func follow(_ proxy: ScrollViewProxy) {
        guard following, !followQueued else { return }
        followQueued = true
        DispatchQueue.main.async {
            followQueued = false
            if following { proxy.scrollTo("chat-bottom", anchor: .bottom) }
        }
    }

    private func row(_ message: LiveChatMessage) -> some View {
        LiveChatBubble(message: message, subtitles: state.subtitles, subdued: subdued)
            .frame(maxWidth: .infinity, alignment: message.mine ? .trailing : .leading)
    }
}

private struct LiveChatBubble: View {
    let message: LiveChatMessage
    let subtitles: String
    let subdued: Bool

    private static let voiceColors: [Color] = [
        Color(red: 0.26, green: 0.49, blue: 0.37), Color(red: 0.48, green: 0.35, blue: 0.52),
        Color(red: 0.37, green: 0.22, blue: 0.13), Color(red: 0.36, green: 0.16, blue: 0.24),
        Color(red: 0.17, green: 0.26, blue: 0.34), Color(red: 0.23, green: 0.27, blue: 0.12)
    ]

    var body: some View {
        let color: Color
        let author: String
        if message.checkingEcho {
            color = Color(white: 0.30)
            author = L("麦克风")
        } else if message.mine {
            color = Color(red: 0.17, green: 0.41, blue: 0.83)
            author = L("你")
        } else if let voice = message.voice, voice >= 0 {
            color = Self.voiceColors[voice % Self.voiceColors.count]
            author = message.name.flatMap { $0.isEmpty ? nil : $0 } ?? L("声音 \(voice + 1)")
        } else {
            color = Color(white: 0.23)
            author = L("对方")
        }
        let original = message.source
        let translation = message.translation
        let showBoth = subtitles == "both" && !original.isEmpty && !translation.isEmpty && original != translation
        let primary = (subtitles == "original" && !original.isEmpty) || translation.isEmpty ? original : translation
        return VStack(alignment: .leading, spacing: 3) {
            if message.checkingEcho || !message.mine {
                Text(verbatim: author).font(.system(size: 12, weight: .medium)).padding(.leading, 3)
            }
            VStack(alignment: .leading, spacing: 2) {
                if showBoth {
                    Text(verbatim: original).font(.system(size: 12)).foregroundStyle(.white.opacity(0.86))
                }
                if message.waitingForWords {
                    SoundBars(height: 15)
                        .frame(width: 30, height: 19)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("你正在说…"))
                } else {
                    Text(verbatim: primary).font(.system(size: 16))
                        .accessibilityLabel(Text(verbatim: message.mine && !message.checkingEcho ? L("你：\(primary)") : primary))
                }
            }
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(subdued ? 0.58 : 0.90)))
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 414, alignment: message.mine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
    }
}
