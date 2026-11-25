import AppKit
import SwiftUI

struct LiveChatMessage: Identifiable, Equatable {
    let id: String
    let mine: Bool
    var source: String
    var translation: String
    var voice: Int?
    var name: String?

    static func recorded(_ line: TranscriptLine, in session: Session) -> Self {
        let name = line.voice.flatMap { voice in
            session.voiceNames?[String(voice)] ?? session.voiceProfiles?[String(voice)]?.name
        }
        return Self(id: line.id, mine: line.speaker == "me", source: line.shown,
                    translation: line.dst ?? "", voice: line.voice, name: name)
    }
}

@MainActor final class LiveChatState: ObservableObject {
    @Published private(set) var sessionID: String?
    @Published private(set) var standalone: [LiveChatMessage] = []
    @Published var incoming: LiveChatMessage?
    @Published var outgoing: LiveChatMessage?
    @Published var subtitles = "both"
    @Published var quiet = true
    @Published private(set) var expanded = false

    func expand() {
        if !expanded { expanded = true }
    }

    func beginMeeting(_ id: String) {
        sessionID = id
        standalone.removeAll()
        clearDrafts()
    }

    func clearDrafts() {
        incoming = nil
        outgoing = nil
    }

    func beginStandalone() {
        guard sessionID != nil else { return }
        sessionID = nil
        clearDrafts()
    }

    func appendStandalone(source: String, translation: String) {
        beginStandalone()
        standalone.append(LiveChatMessage(id: UUID().uuidString, mine: true, source: source, translation: translation))
    }

    func hasMessages(in session: Session?) -> Bool {
        session?.lines.isEmpty == false || !standalone.isEmpty || incoming != nil || outgoing != nil
    }
}

@MainActor final class LiveChatPanel: NSObject {
    private let store: SessionStore
    private let state = LiveChatState()
    private var panel: OverlayPanel?
    private var dim: DispatchWorkItem?
    private var enabled = false
    private var speaking = false
    private var displayID = UserDefaults.standard.object(forKey: "liveChat.display") as? NSNumber

    init(store: SessionStore) {
        self.store = store
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged(_:)),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func screensChanged(_ notification: Notification) { position() }

    /// Picking the tile on a second display pins the chat there across pauses and relaunches.
    func selectScreen() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        displayID = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        UserDefaults.standard.set(displayID, forKey: "liveChat.display")
    }

    func beginMeeting(_ id: String) {
        state.beginMeeting(id)
        rest()
    }

    func endMeeting() {
        state.incoming = nil
        if !speaking { state.outgoing = nil }
    }

    func heard(_ draft: (source: String, translation: String)?) {
        let message = draft.map { LiveChatMessage(id: "draft-them", mine: false, source: $0.source, translation: $0.translation) }
        guard state.incoming != message else { return }
        state.incoming = message
    }

    func said(_ phase: SpeakEngine.Phase, source: String, translation: String, committed: Bool) {
        if phase == .listening, store.liveID == nil { state.beginStandalone() }
        speaking = phase != .idle
        if committed || (phase == .idle && source.isEmpty && translation.isEmpty) {
            state.outgoing = nil
        } else {
            let text = source.isEmpty && translation.isEmpty ? L("你正在说…") : source
            state.outgoing = LiveChatMessage(id: "draft-me", mine: true, source: text, translation: translation)
        }
        if !source.isEmpty && (phase == .listening || !state.expanded) {
            activity()
        } else if phase == .idle && !committed && !translation.isEmpty {
            // A rejected press can have a notice even before any words were recognized.
            activity()
        }
    }

    func appendStandalone(_ source: String, _ translation: String) {
        state.appendStandalone(source: source, translation: translation)
        if !state.expanded { activity() }
    }

    func activity() {
        guard enabled else { return }
        if !state.expanded {
            state.expand()
            position()
        }
        dim?.cancel()
        if state.quiet { state.quiet = false }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.state.quiet = true }
        }
        dim = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    func show(subtitles: String, openHistory: Bool = false) {
        state.subtitles = subtitles
        enabled = true
        if openHistory || state.hasMessages(in: store.session(state.sessionID)) { state.expand() }
        if displayID == nil { selectScreen() }
        if panel == nil {
            let host = FirstClickHostingView(rootView: LiveChatView(store: store, state: state))
            host.sizingOptions = []
            let panel = OverlayPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.contentView = host
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.acceptsMouseMovedEvents = true
            // A hint for legacy capturers. ScreenCaptureKit sharing is controlled by the sender.
            panel.sharingType = .none
            self.panel = panel
        }
        position()
    }

    private func position() {
        guard enabled, let panel else { return }
        // An unplugged private display must not send captions to another screen.
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == displayID
        }) else { panel.orderOut(nil); return }
        let size = state.expanded ? NSSize(width: min(560, screen.visibleFrame.width), height: 250)
                                  : NSSize(width: 108, height: 26)
        let top = min(screen.visibleFrame.maxY, screen.frame.maxY - screen.safeAreaInsets.top) - 5
        let frame = NSRect(x: round(screen.frame.midX - size.width / 2), y: top - size.height,
                           width: size.width, height: size.height)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func rest() {
        dim?.cancel()
        dim = nil
        state.quiet = true
    }

    func hide() {
        enabled = false
        speaking = false
        state.clearDrafts()
        rest()
        panel?.orderOut(nil)
    }
}
