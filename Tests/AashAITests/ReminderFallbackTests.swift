import Foundation
import Testing
@testable import AashAI

@Suite struct ReminderFallbackTests {
    private enum Fixture {
        static func data(_ name: String, file: StaticString = #filePath) throws -> Data {
            let url = URL(fileURLWithPath: "\(file)")
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/gemini")
                .appendingPathComponent(name)
            return try Data(contentsOf: url)
        }
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
        return calendar
    }

    private func ist(_ day: Int, _ hour: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)))
    }

    private func suggestion(_ json: String) throws -> ReminderSuggestion? {
        try ReminderFallback.suggestion(from: Data(json.utf8), calendar: calendar)
    }

    @Test func schemaRequiresIsReminder() throws {
        let object = try #require(try JSONSerialization.jsonObject(with: ReminderFallback.schema) as? [String: Any])
        #expect(object["required"] as? [String] == ["isReminder"])
        let properties = try #require(object["properties"] as? [String: Any])
        #expect(Set(properties.keys) == ["isReminder", "title", "due"])
    }

    @Test func promptStatesNowAndMessage() throws {
        let prompt = ReminderFallback.prompt("remind me to pay the bill on the 25th", now: try ist(18, 10), calendar: calendar)
        #expect(prompt == "Now: Sunday 2026-10-18 10:00\nMessage: remind me to pay the bill on the 25th")
    }

    @Test func fixtureReplyIsCallMum() throws {
        let text = try GeminiWire.replyText(Fixture.data("json-reply.json"))
        let result = try ReminderFallback.suggestion(from: Data(text.utf8), calendar: calendar)
        #expect(result == ReminderSuggestion(title: "Call mum", due: try ist(19, 19)))
    }

    @Test func notAReminderIsNil() throws {
        #expect(try suggestion(#"{"isReminder": false}"#) == nil)
    }

    @Test func missingDueIsNil() throws {
        #expect(try suggestion(#"{"isReminder": true, "title": "Call mum"}"#) == nil)
    }

    @Test func blankTitleIsNil() throws {
        #expect(try suggestion(#"{"isReminder": true, "title": "  ", "due": "2026-10-19T19:00"}"#) == nil)
    }

    @Test func secondsAreAccepted() throws {
        let result = try suggestion(#"{"isReminder": true, "title": "Call mum", "due": "2026-10-19T19:00:00"}"#)
        #expect(result?.due == (try ist(19, 19)))
    }

    @Test func badJSONThrows() {
        #expect(throws: ChatError.self) {
            try ReminderFallback.suggestion(from: Data("nope".utf8), calendar: calendar)
        }
    }
}
