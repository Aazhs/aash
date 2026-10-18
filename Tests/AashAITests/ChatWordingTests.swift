import Foundation
import Testing
@testable import AashAI

@Suite struct ChatWordingTests {
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, timeZone: String) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZone))
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    @Test func systemInstructionIsTheDocumentedText() {
        #expect(ChatPrompts.system == "You are Aash, a small pixel buddy who lives in the user's macOS menu bar. Be warm and brief: at most four short sentences unless asked for more. Plain text only: no headings, tables or markdown. If asked to do something on the Mac, say what the user can do instead.")
    }

    @Test func clipboardMessageJoinsInstructionAndText() {
        #expect(ChatPrompts.clipboardMessage(.summarise, text: "Hello") == "Summarise this in three short bullet points.\n\nHello")
    }

    @Test func clipboardTextIsCutToTheLimit() {
        let message = ChatPrompts.clipboardMessage(.explain, text: String(repeating: "a", count: 25_000))
        let body = String(message.components(separatedBy: "\n\n").dropFirst().joined(separator: "\n\n"))
        #expect(body.count == 20_000)
    }

    @Test func clipboardCutNeverSplitsAnEmoji() {
        let family = "👩‍👩‍👧"
        let text = String(repeating: "a", count: 19_999) + family + " and more text"
        let message = ChatPrompts.clipboardMessage(.rewrite, text: text)
        let body = String(message.components(separatedBy: "\n\n").dropFirst().joined(separator: "\n\n"))
        #expect(body.hasSuffix(family))
    }

    @Test func actionTitlesAreStable() {
        #expect(ChatPrompts.ClipboardAction.allCases.map(\.title) == ["Summarise", "Rewrite", "Explain"])
    }

    @Test func quotaLineShowsLocalResetTime() throws {
        let resetsAt = try Self.date(2026, 10, 18, 7, timeZone: "UTC")
        let line = ChatError.quota(resetsAt: resetsAt).userMessage(
            timeZone: try #require(TimeZone(identifier: "Asia/Kolkata")),
            locale: Locale(identifier: "en_GB"))
        #expect(line == "Free Gemini limit reached for today. It resets at 12:30.")
    }

    @Test func quotaWithoutResetTime() {
        #expect(ChatError.quota(resetsAt: nil).userMessage() == "Free Gemini limit reached for today. Try again later.")
    }

    @Test func otherErrorLines() {
        #expect(ChatError.noKey.userMessage() == "Add your free Gemini key in Settings to chat.")
        #expect(ChatError.badKey.userMessage() == "Gemini didn't accept the key. Check it in Settings.")
        #expect(ChatError.offline.userMessage() == "You're offline. Chat needs the internet; everything else still works.")
        #expect(ChatError.timedOut.userMessage() == "Gemini took too long. Try again?")
        #expect(ChatError.server(status: 500, message: "x").userMessage() == "Something went wrong talking to Gemini.")
        #expect(ChatError.badResponse("y").userMessage() == "Something went wrong talking to Gemini.")
    }

    @Test func serverMessageIsNotShown() {
        #expect(!ChatError.server(status: 500, message: "secret detail").userMessage().contains("secret"))
    }
}
