import AVFoundation

/// Final tokens are append-only; each response replaces the previous draft.
struct SonioxTranscript {
    struct Response: Decodable {
        let tokens: [Token]?
        let finished: Bool?
        let error_code: Int?
    }

    struct Token: Decodable {
        let text: String
        let is_final: Bool
        let translation_status: String?
        let language: String?
        let start_ms: Int?
        let end_ms: Int?
    }

    private var original = ""
    private var translated = ""
    private var targets = Set<String>()
    private var language: String?
    private var start: Int?
    private var end = 0

    private mutating func append(_ token: Token) {
        if token.translation_status == "translation" {
            translated += token.text
            if let language = token.language { targets.insert(language) }
        } else {
            original += token.text
            language = language ?? token.language
            start = start ?? token.start_ms
            end = token.end_ms ?? end
        }
    }

    private func piece(final: Bool) -> Recognition.Piece? {
        let text = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let translation = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        return Recognition.Piece(text: text, isFinal: final, start: Double(start ?? 0) / 1000,
                                 end: Double(end) / 1000, confidence: nil,
                                 language: language == "zh" ? "zh-CN" : language,
                                 translation: translation.isEmpty || targets.count != 1 ? nil : translation,
                                 translationLanguage: targets.count == 1 ? targets.first : nil)
    }

    mutating func consume(_ response: Response) -> [Recognition.Piece] {
        var pieces: [Recognition.Piece] = []
        var draftTokens: [Token] = []
        for token in response.tokens ?? [] {
            if token.text == "<end>" || token.text == "<fin>" {
                if token.is_final {
                    if let line = piece(final: true) { pieces.append(line) }
                    draftTokens.removeAll()
                    self = SonioxTranscript()
                }
            } else if token.is_final {
                append(token)
            } else {
                draftTokens.append(token)
            }
        }
        if response.finished == true {
            if let line = piece(final: true) { pieces.append(line) }
            self = SonioxTranscript()
        } else {
            var draft = self
            // Source words can arrive immediately. Only confirmed translation tokens stay on screen
            // through a revision; the service may withdraw the entire provisional translation.
            for token in draftTokens where token.translation_status != "translation" { draft.append(token) }
            if let line = draft.piece(final: false) { pieces.append(line) }
        }
        return pieces
    }
}

final class SonioxStream: RecognitionStream, @unchecked Sendable {
    static func failureMessage(for error: Error) -> String {
        if let failure = error as? LingClient.Failure,
           [.http(401), .invalidKey, .noKey].contains(failure) {
            return L("请在 AI 服务中检查 Soniox 密钥及其项目区域")
        }
        return L("请检查 Soniox 密钥和模型后重新开始")
    }

    static let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
    var format: AVAudioFormat { Self.audioFormat }
    let results: AsyncThrowingStream<Recognition.Piece, Error>
    private let output: AsyncThrowingStream<Recognition.Piece, Error>.Continuation
    private let frames: AsyncStream<URLSessionWebSocketTask.Message>.Continuation
    private let socket: URLSessionWebSocketTask
    private let run: Task<Void, Never>

    init(socket: URLSessionWebSocketTask, model: String, hint: String?, target: String?, otherLanguage: String?,
         permit: @escaping @MainActor @Sendable () async -> Void) throws {
        self.socket = socket
        var config: [String: Any] = ["model": model, "audio_format": "pcm_s16le", "sample_rate": 16000,
                                     "num_channels": 1, "enable_language_identification": true,
                                     "enable_endpoint_detection": true]
        if let hint { config["language_hints"] = [VoiceCatalog.key(for: hint)] }
        if let target {
            let to = VoiceCatalog.key(for: target)
            if let otherLanguage, VoiceCatalog.key(for: otherLanguage) != to {
                config["translation"] = ["type": "two_way", "language_a": to, "language_b": VoiceCatalog.key(for: otherLanguage)]
            } else {
                config["translation"] = ["type": "one_way", "target_language": to]
            }
        }
        let json = String(decoding: try JSONSerialization.data(withJSONObject: config), as: UTF8.self)
        let (input, frames) = AsyncStream<URLSessionWebSocketTask.Message>.makeStream(bufferingPolicy: .bufferingOldest(256))
        self.frames = frames
        let (results, output) = AsyncThrowingStream<Recognition.Piece, Error>.makeStream()
        self.results = results
        self.output = output
        run = Task {
            defer {
                frames.finish()
                socket.cancel(with: .normalClosure, reason: nil)
            }
            do {
                await permit()
                try Task.checkCancellation()
                socket.resume()
                try await socket.send(.string(json))
                // A process tap can go silent for minutes without delivering a buffer.
                let keepalive = Task {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(8))
                        frames.yield(.string(#"{"type":"keepalive"}"#))
                    }
                }
                defer { keepalive.cancel() }
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        do {
                            var lastSent = Date()
                            for await frame in input {
                                try Task.checkCancellation()
                                if case .string = frame, Date().timeIntervalSince(lastSent) < 7 { continue }
                                try await socket.send(frame)
                                lastSent = Date()
                            }
                            try Task.checkCancellation()
                            try await socket.send(.string(""))
                        } catch {
                            socket.cancel(with: .goingAway, reason: nil)
                            throw error
                        }
                    }
                    defer {
                        frames.finish()
                        group.cancelAll()
                        socket.cancel(with: .normalClosure, reason: nil)
                    }
                    var transcript = SonioxTranscript()
                    while !Task.isCancelled {
                        let bytes: Data
                        switch try await socket.receive() {
                        case .string(let text): bytes = Data(text.utf8)
                        case .data(let data): bytes = data
                        @unknown default: throw LingClient.Failure.parse
                        }
                        let response = try JSONDecoder().decode(SonioxTranscript.Response.self, from: bytes)
                        if let code = response.error_code { throw LingClient.Failure.http(code) }
                        for piece in transcript.consume(response) { output.yield(piece) }
                        if response.finished == true { break }
                    }
                }
                output.finish()
            } catch {
                output.finish(throwing: error)
            }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0, let samples = buffer.int16ChannelData?[0] else { return }
        let data = Data(bytes: samples, count: Int(buffer.frameLength) * MemoryLayout<Int16>.size)
        if case .dropped = frames.yield(.data(data)) {
            output.finish(throwing: LingClient.Failure.network)
            close()
        }
    }

    // Soniox supplies its own endpoint boundaries while audio is still arriving.
    func finalize(through seconds: Double) async throws {}

    func finish() async {
        frames.finish()
        let timeout = Task { [socket] in
            try await Task.sleep(for: .seconds(15))
            socket.cancel(with: .goingAway, reason: nil)
        }
        await run.value
        timeout.cancel()
    }

    private func close() {
        run.cancel()
        frames.finish()
        socket.cancel(with: .goingAway, reason: nil)
    }

    func cancel() async {
        close()
        output.finish()
    }
}
