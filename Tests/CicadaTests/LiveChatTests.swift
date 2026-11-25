import AVFoundation
import Foundation
import Testing
@testable import Cicada

struct LiveChatTests {
    @MainActor @Test func pushToTalkOverridesTheSavedAutoOpenMicrophoneChoice() throws {
        let suite = "cicada-press-only-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.autoMicOnStart = true
        settings.speakEnabled = true
        settings.speakHandsFree = false
        let reopened = AppSettings(defaults: defaults)
        #expect(reopened.pushToTalkOnly && !reopened.autoOpenMeetingMic)
        reopened.speakHandsFree = true
        #expect(!reopened.pushToTalkOnly && reopened.autoOpenMeetingMic)
        reopened.speakHandsFree = false
        reopened.speakEnabled = false
        #expect(!reopened.pushToTalkOnly && reopened.autoOpenMeetingMic)
    }

    @Test func micAndComputerKeepTheirOwnSideEvenWhenTheySpeakTheSameLanguage() {
        let inputs = [MeetingInput(microphone: true, personal: true),
                      MeetingInput(microphone: false, personal: true),
                      MeetingInput(microphone: true, personal: false)]
        let session = Session(id: "s", title: "", startedAt: Date(), endedAt: nil, lines: [], hasAudio: false)
        for (index, input) in inputs.enumerated() {
            let segment = Segment(id: index, text: "Bonjour", sourceCode: "fr", input: input)
            let draft = LiveChatMessage.heard(segment)
            let line = TranscriptLine(id: draft.id, t: 0, speaker: input.speaker, src: segment.text,
                                      srcLang: "fr", dstLang: "fr", via: input.via)
            #expect(draft.mine == (index == 0))
            #expect(LiveChatMessage.recorded(line, in: session).mine == draft.mine)
            #expect(!line.isInterpretedSpeech)
            #expect(LiveChatMessage.heard(segment, checkingEcho: true).checkingEcho == (index == 0))
            #expect(!draft.checkingEcho)
        }
        let press = TranscriptLine(id: "m1", t: 1, speaker: "me", src: "Bonjour", srcLang: "fr", dstLang: "de")
        #expect(press.isInterpretedSpeech)
    }

    @MainActor @Test func changingTheMicPreferenceCannotRelabelAudioAlreadyInTheRecognizer() throws {
        let suite = "cicada-mic-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.speechServices.soniox = true
        let engine = ListenEngine(settings: settings)
        let previousLocale = ListenEngine.silentLocale
        ListenEngine.silentLocale = "fr-FR"
        defer { engine.stop(); ListenEngine.silentLocale = previousLocale }
        engine.translationOff = { true }
        var inputs: [MeetingInput] = []
        engine.onFinal = { segment, _ in inputs.append(segment.input) }

        settings.listenSource = "system"
        engine.start()
        settings.listenSource = "room"
        settings.personalMicrophone = true
        engine.debugHeard("Last computer sentence")
        engine.listenSourceChanged()
        settings.personalMicrophone = false
        engine.debugHeard("Last personal sentence")
        engine.listenSourceChanged()
        engine.debugHeard("Shared room sentence")
        #expect(inputs == [.computer, .personalMic, .sharedMic])
    }

    @MainActor @Test func switchingInputsKeepsSpeechEvidenceWhenNoWordsWereRecognized() throws {
        let suite = "cicada-recording-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.speechServices.soniox = true
        let engine = ListenEngine(settings: settings)
        let previousLocale = ListenEngine.silentLocale
        ListenEngine.silentLocale = "fr-FR"
        defer { ListenEngine.silentLocale = previousLocale }
        engine.start()

        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let audio = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 64000))
        audio.frameLength = audio.frameCapacity
        let samples = try #require(audio.floatChannelData?[0])
        for frame in 0..<Int(audio.frameLength) { samples[frame] = 0.2 }
        engine.router.push(audio)
        #expect(engine.router.stats().voicedTotal >= 3)
        settings.listenSource = "room"
        engine.listenSourceChanged()
        engine.stop()
        #expect(engine.heardSpeech)
        engine.resetMeetingSpeech()
        engine.start()
        engine.stop()
        #expect(!engine.heardSpeech)
    }

    @Test func talkIndicatorGivesWayToWordsOrANotice() {
        var message = LiveChatMessage(id: "draft-me", mine: true, source: "", translation: "")
        #expect(message.waitingForWords)
        message.source = "Bonjour"
        #expect(!message.waitingForWords)
        message.source = ""
        message.translation = "Microphone unavailable"
        #expect(!message.waitingForWords)
    }

    @MainActor @Test func silenceAndClearedDraftsKeepTheOpenedWindowExpanded() {
        let state = LiveChatState()
        state.beginMeeting("one")
        #expect(!state.expanded)
        state.expand()
        state.quiet = true
        state.clearDrafts()
        #expect(state.expanded && !state.hasMessages(in: nil))
        state.beginStandalone()
        #expect(state.expanded)
    }

    @Test func recordedLinesKeepTheirIdentityAndAssignedVoice() {
        let line = TranscriptLine(id: "reply", t: 0, speaker: "them", src: "Hello", dst: "Bonjour",
                                  srcLang: "en", dstLang: "fr", voice: 0)
        let session = Session(id: "meeting", title: "", startedAt: Date(), endedAt: nil,
                              lines: [line], hasAudio: false, voiceNames: ["0": "Camille"])
        let message = LiveChatMessage.recorded(line, in: session)
        #expect(message.id == line.id && message.name == "Camille" && message.voice == 0)
        #expect(!message.mine && message.source == "Hello" && message.translation == "Bonjour")
    }

    @MainActor @Test func standaloneHistoryOutlastsDraftsAndStartsFreshAtTheNextMeeting() {
        let state = LiveChatState()
        for number in 1...8 {
            state.appendStandalone(source: String(number), translation: "")
        }
        state.clearDrafts()
        #expect(state.standalone.map(\.source) == (1...8).map { String($0) })
        #expect(Set(state.standalone.map(\.id)).count == 8)
        state.beginMeeting("first")
        #expect(state.sessionID == "first" && !state.hasMessages(in: nil))
        state.clearDrafts()
        #expect(state.sessionID == "first")
        state.appendStandalone(source: "After the meeting", translation: "")
        #expect(state.sessionID == nil && state.standalone.count == 1)
    }
}
