import Foundation

/// macOS live audio overrides. Only non-secret choices are encoded into preferences.
struct SpeechServices: Codable, Equatable {
    var soniox = false
    var sonioxModel = "stt-rt-v6"
    var directTranslation = true
    var elevenLabs = false
    var voiceModel = "eleven_flash_v2_5"
    var voiceID = ""
    var voiceName = ""
}

/// Both credentials belong to fixed provider origins, including across redirects.
private final class SpeechSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

extension LingClient {
    private static let speechSession = URLSession(configuration: .ephemeral, delegate: SpeechSessionDelegate(), delegateQueue: nil)
    private static let elevenBase = URL(string: "https://api.elevenlabs.io")!

    func sonioxStream(settings: SpeechServices, hint: String?, target: String?, otherLanguage: String?,
                      priority: Priority) throws -> SonioxStream {
        guard !hideKey, let key = AIKey.read("soniox") else { throw Failure.noKey }
        let url = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return try SonioxStream(socket: Self.speechSession.webSocketTask(with: request), model: settings.sonioxModel,
                                hint: hint, target: target, otherLanguage: otherLanguage) {
            await self.waitForSpeechService(priority, url: url)
        }
    }

    struct ElevenVoice: Decodable, Identifiable {
        let voice_id: String
        let name: String?
        var id: String { voice_id }
    }

    func elevenVoices(key: String) async throws -> [ElevenVoice] {
        struct Page: Decodable {
            let voices: [ElevenVoice]
            let has_more: Bool
            let next_page_token: String?
        }
        var voices: [ElevenVoice] = []
        var cursor: String?
        var seen = Set<String>()
        repeat {
            var query = [URLQueryItem(name: "page_size", value: "100")]
            if let cursor { query.append(URLQueryItem(name: "next_page_token", value: cursor)) }
            let url = Self.elevenBase.appendingPathComponent("v2/voices").appending(queryItems: query)
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue(key, forHTTPHeaderField: "xi-api-key")
            await waitForSpeechService(.notes, url: url)
            try Task.checkCancellation()
            let (data, response) = try await Self.speechSession.data(for: request)
            try Self.checkSpeechResponse(response)
            let page = try JSONDecoder().decode(Page.self, from: data)
            voices.append(contentsOf: page.voices)
            if !page.has_more { break }
            guard let token = page.next_page_token, seen.insert(token).inserted else { throw Failure.parse }
            cursor = token
        } while true
        return voices
    }

    func elevenSpeech(_ text: String, settings: SpeechServices) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { output in
            let task = Task {
                do {
                    guard !hideKey, let key = AIKey.read("elevenlabs") else { throw Failure.noKey }
                    guard !settings.voiceID.isEmpty, settings.voiceID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
                        throw Failure.parse
                    }
                    let url = Self.elevenBase.appendingPathComponent("v1/text-to-speech")
                        .appendingPathComponent(settings.voiceID).appendingPathComponent("stream")
                        .appending(queryItems: [URLQueryItem(name: "output_format", value: "pcm_24000")])
                    var request = URLRequest(url: url, timeoutInterval: 20)
                    request.httpMethod = "POST"
                    request.setValue(key, forHTTPHeaderField: "xi-api-key")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(["model_id": settings.voiceModel, "text": text])
                    await waitForSpeechService(.speak, url: url)
                    try Task.checkCancellation()
                    let (bytes, response) = try await Self.speechSession.bytes(for: request)
                    try Self.checkSpeechResponse(response)
                    var chunk = Data()
                    for try await byte in bytes {
                        chunk.append(byte)
                        if chunk.count == 4800 {
                            output.yield(chunk)
                            chunk.removeAll(keepingCapacity: true)
                        }
                    }
                    if !chunk.isEmpty { output.yield(chunk) }
                    output.finish()
                } catch {
                    output.finish(throwing: error)
                }
            }
            output.onTermination = { _ in task.cancel() }
        }
    }

    private static func checkSpeechResponse(_ response: URLResponse) throws {
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: return
        case 401, 403: throw Failure.invalidKey
        case 429: throw Failure.rateLimited
        case let code: throw Failure.http(code)
        }
    }
}
