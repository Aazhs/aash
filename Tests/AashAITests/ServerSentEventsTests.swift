import Testing
@testable import AashAI

@Suite struct ServerSentEventsTests {
    @Test func dataLineAloneIsAnEvent() {
        var parser = ServerSentEventParser()
        #expect(parser.feed("data: {\"a\":1}") == ServerSentEvent(name: nil, data: "{\"a\":1}"))
    }

    @Test func eventNameAttachesToNextData() {
        var parser = ServerSentEventParser()
        #expect(parser.feed("event: step.delta") == nil)
        #expect(parser.feed("data: x") == ServerSentEvent(name: "step.delta", data: "x"))
    }

    @Test func nameIsClearedAfterUse() {
        var parser = ServerSentEventParser()
        _ = parser.feed("event: step.delta")
        _ = parser.feed("data: x")
        #expect(parser.feed("data: y") == ServerSentEvent(name: nil, data: "y"))
    }

    @Test func blankAndCommentLinesAreIgnored() {
        var parser = ServerSentEventParser()
        #expect(parser.feed("") == nil)
        #expect(parser.feed(": keep-alive") == nil)
    }

    @Test func doneSentinelIsPassedThrough() {
        var parser = ServerSentEventParser()
        _ = parser.feed("event: done")
        #expect(parser.feed("data: [DONE]") == ServerSentEvent(name: "done", data: "[DONE]"))
    }

    @Test func noSpaceAfterColonStillWorks() {
        var parser = ServerSentEventParser()
        #expect(parser.feed("data:abc")?.data == "abc")
    }

    @Test func chatErrorsCompare() {
        #expect(ChatError.quota(resetsAt: nil) == .quota(resetsAt: nil))
        #expect(ChatError.server(status: 500, message: "x") != .server(status: 500, message: "y"))
    }
}
