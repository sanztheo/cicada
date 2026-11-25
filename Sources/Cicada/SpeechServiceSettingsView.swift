import SwiftUI

struct SpeechServiceSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @State private var draft = SpeechServices()
    @State private var voices: [LingClient.ElevenVoice] = []
    @State private var message = ""
    @State private var loading = false
    @State private var elevenKeyVersion = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("实时语音服务").font(.headline)
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("用 Soniox 识别会议和按键发言", isOn: $draft.soniox)
                    if draft.soniox {
                        SpeechServiceKey(service: "soniox") { message = "" }
                        Picker(L("Soniox 项目区域"), selection: Binding(
                            get: { draft.sonioxRegion ?? .us },
                            set: { draft.sonioxRegion = $0 }
                        )) {
                            ForEach(SonioxRegion.allCases, id: \.self) { region in
                                Text(verbatim: region.name).tag(region)
                            }
                        }
                        TextField(L("语音识别"), text: $draft.sonioxModel)
                        Picker(L("翻译"), selection: $draft.directTranslation) {
                            Text(verbatim: "Soniox").tag(true)
                            Text("文字模型").tag(false)
                        }
                    }
                    Divider()
                    Toggle("用 ElevenLabs 朗读译文", isOn: $draft.elevenLabs)
                    if draft.elevenLabs {
                        SpeechServiceKey(service: "elevenlabs") {
                            elevenKeyVersion += 1
                            voices = []
                            message = ""
                        }
                        TextField(L("声音模型"), text: $draft.voiceModel)
                        HStack {
                            Button("获取声音") { fetchVoices() }.disabled(loading)
                            if loading { ProgressView().controlSize(.small) }
                            if !voices.isEmpty {
                                Menu(draft.voiceName.isEmpty ? L("声音") : draft.voiceName) {
                                    ForEach(voices) { voice in
                                        Button(voice.name ?? voice.id) {
                                            draft.voiceID = voice.id
                                            draft.voiceName = voice.name ?? voice.id
                                        }
                                    }
                                }
                            }
                        }
                        TextField("Voice ID", text: Binding(get: { draft.voiceID }, set: {
                            draft.voiceID = $0
                            draft.voiceName = ""
                        }))
                    }
                    HStack {
                        Button("保存") { save() }
                        if !message.isEmpty { Text(message).font(.caption) }
                    }
                }
                .padding(14)
                .disabled(settings.onlyCustomService || model.running || model.speakPhase != .idle)
            }
            Text(settings.onlyCustomService ? L("仅使用自定义服务时，外部语音服务已停用")
                 : model.running || model.speakPhase != .idle ? L("结束聆听和发言后可修改")
                 : L("打开后，音频发给 Soniox，朗读的译文发给 ElevenLabs。各项可单独启用。"))
                .font(.caption).foregroundStyle(Palette.secondary)
        }
        .onAppear { draft = settings.speechServices }
    }

    private func fetchVoices() {
        guard let key = AIKey.read("elevenlabs") else { message = L("请先保存对应的 API key"); return }
        let version = elevenKeyVersion
        loading = true
        Task {
            defer { loading = false }
            do {
                let available = try await model.ling.elevenVoices(key: key)
                guard version == elevenKeyVersion else { return }
                voices = available
                message = available.isEmpty ? L("没有可用的声音") : ""
            } catch {
                if version == elevenKeyVersion { message = L("获取声音失败，可填写 Voice ID") }
            }
        }
    }

    private func save() {
        draft.sonioxModel = draft.sonioxModel.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.voiceModel = draft.voiceModel.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.voiceID = draft.voiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if (draft.soniox && AIKey.read("soniox") == nil) || (draft.elevenLabs && AIKey.read("elevenlabs") == nil) {
            message = L("请先保存对应的 API key")
            return
        }
        if (draft.soniox && draft.sonioxModel.isEmpty) || (draft.elevenLabs && (draft.voiceModel.isEmpty || draft.voiceID.isEmpty)) {
            message = L("请填写模型和所选声音的 ID")
            return
        }
        if (draft.soniox && !settings.speechServices.soniox) || (draft.elevenLabs && !settings.speechServices.elevenLabs) {
            settings.speakHandsFree = false
        }
        settings.speechServices = draft
        model.applyAIService()
        model.refreshPermissions()
        message = L("设置已保存")
    }
}

private struct SpeechServiceKey: View {
    let service: String
    let changed: () -> Void
    @State private var key = ""
    @State private var saved = false
    @State private var failed = false

    var body: some View {
        HStack {
            SecureField(saved ? L("已保存密钥") : "API key", text: $key)
            Button("保存") {
                let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                failed = !AIKey.save(value, service)
                if !failed { key = ""; saved = true; changed() }
            }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if saved {
                Button("移除 key") {
                    AIKey.remove(service)
                    key = ""
                    saved = false
                    failed = false
                    changed()
                }
            }
            if failed { Text("密钥保存失败").font(.caption) }
        }
        .onAppear { saved = AIKey.read(service) != nil }
    }
}
