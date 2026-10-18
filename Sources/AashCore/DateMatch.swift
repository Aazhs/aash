import Foundation

/// A date or time found in a reminder phrase, described without reference to today's date.
public struct DateMatch: Equatable, Sendable {
    /// Which day the phrase names.
    public enum Day: Equatable, Sendable {
        /// No day is named: "at 6", "4:30pm", "midnight".
        case unspecified
        /// Days after today: "today" and "tonight" 0, "tomorrow" 1, "day after tomorrow" 2.
        case relative(Int)
        /// A weekday by name, numbered as `Calendar` does: 1 is Sunday, 7 is Saturday.
        case weekday(Int)
        /// A calendar date; `year` is nil unless the phrase has a four-digit year.
        case date(year: Int?, month: Int, day: Int)
    }

    /// Which time the phrase names.
    public enum Time: Equatable, Sendable {
        /// No time is named: "on Friday", "25 October".
        case unspecified
        /// A time that can't mean morning or evening: am/pm, 24-hour, or a word such as "evening".
        case exact(hour: Int, minute: Int)
        /// A clock hour 1–12 with no am or pm: "at 6", "6:30".
        case clock(hour: Int, minute: Int)
        /// A delay from now: "in 2 hours".
        case later(minutes: Int)
    }

    /// Where the date phrase is in the text it was found in.
    public var range: Range<String.Index>
    /// The day the phrase names.
    public var day: Day
    /// The time the phrase names.
    public var time: Time

    /// Creates a match.
    public init(range: Range<String.Index>, day: Day, time: Time) {
        self.range = range
        self.day = day
        self.time = time
    }
}
