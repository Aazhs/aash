import Foundation
import Testing
@testable import AashCore

private let phraseIST: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .gmt
    return c
}()

private func on(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10, year: Int = 2026) -> Date {
    phraseIST.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
}

private struct Row: Sendable, CustomTestStringConvertible {
    let text: String
    var now: Date = on(18, 10)
    let title: String
    let due: Date
    var testDescription: String { "\(text) @ \(now)" }
}

private let rows: [Row] = [
    Row(text: "Remind me to call mum at 7", title: "Call mum", due: on(18, 19)),
    Row(text: "REMIND ME TO call mum at 7", title: "Call mum", due: on(18, 19)),
    Row(text: "remind me tomorrow to call mum", title: "Call mum", due: on(19, 9)),
    Row(text: "reminder: dentist at 4:30pm", title: "Dentist", due: on(18, 16, 30)),
    Row(text: "remember to water the plants at 8", title: "Water the plants", due: on(18, 20)),
    Row(text: "remind me to call the bank tomorrow at 9am", title: "Call the bank", due: on(19, 9)),
    Row(text: "remind me to submit the lab report at 6", title: "Submit the lab report", due: on(18, 18)),
    Row(text: "remind me to submit the lab report at 6", now: on(18, 19), title: "Submit the lab report", due: on(19, 18)),
    Row(text: "Remind me to call Ravi at 6:30", now: on(18, 3), title: "Call Ravi", due: on(18, 18, 30)),
    Row(text: "remind me to call mum at 12", title: "Call mum", due: on(18, 12)),
    Row(text: "remind me to call mum at 11", now: on(18, 23, 30), title: "Call mum", due: on(19, 11)),
    Row(text: "remind me to call mum tomorrow at 7", title: "Call mum", due: on(19, 7)),
    Row(text: "remind me to call mum at 6 tomorrow", title: "Call mum", due: on(19, 18)),
    Row(text: "remind me to pay rent on Friday", title: "Pay rent", due: on(23, 9)),
    Row(text: "remind me to pay rent on Sunday", title: "Pay rent", due: on(25, 9)),
    Row(text: "remind me to book tickets next Friday at 5 pm", title: "Book tickets", due: on(23, 17)),
    Row(text: "remind me to submit the form on 25 October", title: "Submit the form", due: on(25, 9)),
    Row(text: "remind me to file taxes on 5 October", title: "File taxes", due: on(5, 9, month: 10, year: 2027)),
    Row(text: "remind me to call mum on 25 Oct 2027", title: "Call mum", due: on(25, 9, month: 10, year: 2027)),
    Row(text: "remind me to call mum at 7:30 am", title: "Call mum", due: on(19, 7, 30)),
    Row(text: "remind me to call mum at midnight", title: "Call mum", due: on(19, 0)),
    Row(text: "remind me to call mum at 19:00", title: "Call mum", due: on(18, 19)),
    Row(text: "remind me to pay the electricity bill tomorrow evening", title: "Pay the electricity bill", due: on(19, 18)),
    Row(text: "remind me to call papa tonight", title: "Call papa", due: on(18, 19)),
    Row(text: "remind me submit assignment by 11 pm", title: "Submit assignment", due: on(18, 23)),
    Row(text: "remind me to renew passport day after tomorrow", title: "Renew passport", due: on(20, 9)),
    Row(text: "remind me to take medicine in 2 hours", title: "Take medicine", due: on(18, 12)),
]

@Test(arguments: rows)
private func parsesPhrases(row: Row) {
    let parsed = ReminderPhraseParser.parse(row.text, now: row.now, calendar: phraseIST)
    #expect(parsed == ParsedReminder(title: row.title, due: row.due))
}

private struct NilRow: Sendable, CustomTestStringConvertible {
    let text: String
    var now: Date = on(18, 10)
    var testDescription: String { text }
}

private let nilRows: [NilRow] = [
    NilRow(text: "remind me to buy milk"),
    NilRow(text: "remind me at 6"),
    NilRow(text: "what time is it in London?"),
    NilRow(text: "remind me to call mum today at 9am"),
    NilRow(text: "remind me to call mum on 25 Oct 2025"),
]

@Test(arguments: nilRows)
private func givesNil(row: NilRow) {
    #expect(ReminderPhraseParser.parse(row.text, now: row.now, calendar: phraseIST) == nil)
}

@Test(arguments: [
    ("Remind me to x", true), ("  remember to x", true), ("reminder: x", true),
    ("remind me tomorrow", true), ("remind meeting notes", false),
    ("What's a reminder?", false), ("hello", false),
])
private func detectsRequests(text: String, expected: Bool) {
    #expect(ReminderPhraseParser.isReminderRequest(text) == expected)
}

@Test private func clockOnAGivenDayPrefersTheDaytimeHour() {
    let s = "x"
    let match = DateMatch(range: s.startIndex..<s.endIndex, day: .relative(1), time: .clock(hour: 9, minute: 0))
    #expect(ReminderPhraseParser.resolve(match, now: on(18, 10), calendar: phraseIST) == on(19, 9))
}

@Test private func titleDropsJoiningWords() throws {
    let s = "pay rent on Friday"
    let range = try #require(s.range(of: "Friday"))
    #expect(ReminderPhraseParser.title(s, cutting: range) == "Pay rent")
}
