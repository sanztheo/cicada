import Foundation
import Testing
@testable import Cicada

struct LiveChatTests {
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
