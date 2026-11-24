import Foundation
import Testing
@testable import Cicada

struct SonioxTranscriptTests {
    private func reply(_ json: String) throws -> SonioxTranscript.Response {
        try JSONDecoder().decode(SonioxTranscript.Response.self, from: Data(json.utf8))
    }

    @Test func revisedDraftsNeverReachTheFinalTranslation() throws {
        var transcript = SonioxTranscript()
        let draft = try reply("""
        {"tokens":[{"text":"Hello","is_final":true,"language":"en","start_ms":100,"end_ms":800},
                   {"text":"Salut","is_final":false,"language":"fr","translation_status":"translation"}]}
        """)
        #expect(transcript.consume(draft).first?.translation == "Salut")
        let end = try reply("""
        {"tokens":[{"text":"Bonjour","is_final":true,"language":"fr","translation_status":"translation"},
                   {"text":"<end>","is_final":true}]}
        """)
        let line = try #require(transcript.consume(end).first)
        #expect(line.isFinal && line.text == "Hello" && line.translation == "Bonjour")
        #expect(line.start == 0.1 && line.end == 0.8)
        #expect(transcript.consume(try reply(#"{"finished":true}"#)).isEmpty)
    }

    @Test func endOfInputKeepsOnlyConfirmedOriginals() throws {
        var transcript = SonioxTranscript()
        let end = try reply("""
        {"tokens":[{"text":"Goodbye","is_final":true},{"text":"later","is_final":false}],
         "finished":true}
        """)
        let line = try #require(transcript.consume(end).first)
        #expect(line.isFinal && line.text == "Goodbye" && line.translation == nil)
    }

    @Test func externalAudioIsOptInAndSettingsRoundTrip() throws {
        var choices = SpeechServices()
        #expect(!choices.soniox && !choices.elevenLabs)
        choices.elevenLabs = true
        choices.voiceID = "voice-from-my-library"
        let data = try JSONEncoder().encode(choices)
        #expect(try JSONDecoder().decode(SpeechServices.self, from: data) == choices)
    }
}
