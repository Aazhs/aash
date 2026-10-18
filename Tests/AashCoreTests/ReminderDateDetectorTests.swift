import Testing
@testable import AashCore

private struct Row: Sendable, CustomTestStringConvertible {
    let text: String
    let matched: String
    let day: DateMatch.Day
    let time: DateMatch.Time
    var testDescription: String { text }
}

private let rows: [Row] = [
    Row(text: "remind me to call the bank tomorrow at 9am", matched: "tomorrow at 9am", day: .relative(1), time: .exact(hour: 9, minute: 0)),
    Row(text: "remind me to pay the electricity bill tomorrow evening", matched: "tomorrow evening", day: .relative(1), time: .exact(hour: 18, minute: 0)),
    Row(text: "remind me to call mum tomorrow afternoon", matched: "tomorrow afternoon", day: .relative(1), time: .exact(hour: 15, minute: 0)),
    Row(text: "remind me to pay rent on Friday", matched: "Friday", day: .weekday(6), time: .unspecified),
    Row(text: "remind me to book tickets next Friday at 5 pm", matched: "next Friday at 5 pm", day: .weekday(6), time: .exact(hour: 17, minute: 0)),
    Row(text: "remind me to call mum at 6 on Friday", matched: "at 6 on Friday", day: .weekday(6), time: .clock(hour: 6, minute: 0)),
    Row(text: "reminder: dentist at 4:30pm", matched: "4:30pm", day: .unspecified, time: .exact(hour: 16, minute: 30)),
    Row(text: "remind me to call papa tonight", matched: "tonight", day: .relative(0), time: .exact(hour: 19, minute: 0)),
    Row(text: "remind me to submit the form on 25 October", matched: "25 October", day: .date(year: nil, month: 10, day: 25), time: .unspecified),
    Row(text: "remind me to call mum on 25 Oct 2027", matched: "25 Oct 2027", day: .date(year: 2027, month: 10, day: 25), time: .unspecified),
    Row(text: "remind me to pay fees on 25/10", matched: "25/10", day: .date(year: nil, month: 10, day: 25), time: .unspecified),
    Row(text: "remind me to call Ravi at 6:30", matched: "6:30", day: .unspecified, time: .clock(hour: 6, minute: 30)),
    Row(text: "Remind me to call mum at 7:00", matched: "7:00", day: .unspecified, time: .clock(hour: 7, minute: 0)),
    Row(text: "remind me to call mum at 7 tomorrow", matched: "at 7 tomorrow", day: .relative(1), time: .clock(hour: 7, minute: 0)),
    Row(text: "remind me to call mum today at 5", matched: "today at 5", day: .relative(0), time: .clock(hour: 5, minute: 0)),
    Row(text: "remind me to call mum at 19:00", matched: "19:00", day: .unspecified, time: .exact(hour: 19, minute: 0)),
    Row(text: "remind me to call mum at midnight", matched: "midnight", day: .unspecified, time: .exact(hour: 0, minute: 0)),
    Row(text: "remind me to renew passport day after tomorrow", matched: "day after tomorrow", day: .relative(2), time: .unspecified),
    Row(text: "remind me to call mum at 7", matched: "at 7", day: .unspecified, time: .clock(hour: 7, minute: 0)),
    Row(text: "remind me to call mum at 7.30", matched: "at 7.30", day: .unspecified, time: .clock(hour: 7, minute: 30)),
    Row(text: "remind me to take medicine in 2 hours", matched: "in 2 hours", day: .unspecified, time: .later(minutes: 120)),
    Row(text: "remind me to call mum in 30 minutes", matched: "in 30 minutes", day: .unspecified, time: .later(minutes: 30)),
    Row(text: "remind me to call mum in an hour", matched: "in an hour", day: .unspecified, time: .later(minutes: 60)),
]

@Test(arguments: rows)
private func detectsDateAndTime(row: Row) throws {
    let match = try #require(ReminderDateDetector.detect(row.text))
    #expect(String(row.text[match.range]) == row.matched)
    #expect(match.day == row.day)
    #expect(match.time == row.time)
}

@Test(arguments: [
    "remind me to buy milk",
    "what time is it in London?",
    "remind me to finish by tomorrow",
    "remind me to do yoga at 0630",
])
func findsNothing(text: String) {
    #expect(ReminderDateDetector.detect(text) == nil)
}
