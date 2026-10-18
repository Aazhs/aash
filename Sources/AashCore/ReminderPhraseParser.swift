import Foundation

/// A reminder read from a chat message.
public struct ParsedReminder: Equatable, Sendable {
    /// What to do, first letter capitalised: "Submit the lab report".
    public var title: String
    /// When it's due.
    public var due: Date

    /// Creates a parsed reminder.
    public init(title: String, due: Date) {
        self.title = title
        self.due = due
    }
}

/// Reads "remind me to … at 6" phrases (docs/reminders.md#phrase-parsing-t20-t35).
public enum ReminderPhraseParser {
    /// The phrases that start a reminder, checked in this order so "remind me to" wins over "remind me".
    public static let triggers = ["remind me to", "remind me", "reminder:", "remember to"]

    /// True when `text` starts with a trigger, in any case, after leading spaces.
    public static func isReminderRequest(_ text: String) -> Bool {
        body(text) != nil
    }

    /// The title and due date in `text`, or nil when it isn't a reminder, has no usable date or
    /// time, has an empty title, or names a time that isn't after `now`.
    public static func parse(_ text: String, now: Date, calendar: Calendar) -> ParsedReminder? {
        guard let rest = body(text),
              let match = ReminderDateDetector.detect(rest) else { return nil }
        let title = title(rest, cutting: match.range)
        guard !title.isEmpty,
              let due = resolve(match, now: now, calendar: calendar) else { return nil }
        return ParsedReminder(title: title, due: due)
    }

    /// The first moment after `now` that `match` names, by the rules table; nil when there is none.
    static func resolve(_ match: DateMatch, now: Date, calendar: Calendar) -> Date? {
        if case .later(let minutes) = match.time {
            let due = now.addingTimeInterval(Double(minutes) * 60)
            return due > now ? due : nil
        }
        let today = calendar.startOfDay(for: now)
        func day(_ n: Int) -> Date? { calendar.date(byAdding: .day, value: n, to: today) }

        var days: [Date] = []
        switch match.day {
        case .unspecified:
            days = [day(0), day(1)].compactMap { $0 }
        case .relative(let n):
            days = [day(n)].compactMap { $0 }
        case .weekday(let w):
            let ahead = (w - calendar.component(.weekday, from: now) + 7) % 7
            days = [day(ahead == 0 ? 7 : ahead)].compactMap { $0 }
        case .date(let year, let month, let dom):
            let thisYear = calendar.component(.year, from: now)
            if let year {
                days = [validDate(year, month, dom, calendar)].compactMap { $0 }
            } else if let d = validDate(thisYear, month, dom, calendar) {
                days = [d >= today ? d : validDate(thisYear + 1, month, dom, calendar)].compactMap { $0 }
            }
        }

        var candidates: [Date?] = []
        var isClock = false
        for d in days {
            switch match.time {
            case .unspecified:
                if case .unspecified = match.day { return nil }
                candidates.append(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: d))
            case .exact(let h, let m):
                candidates.append(calendar.date(bySettingHour: h, minute: m, second: 0, of: d))
            case .clock(let h, let m):
                isClock = true
                candidates.append(calendar.date(bySettingHour: h % 12, minute: m, second: 0, of: d))
                candidates.append(calendar.date(bySettingHour: h % 12 + 12, minute: m, second: 0, of: d))
            case .later:
                return nil
            }
        }
        let future = candidates.compactMap { $0 }.filter { $0 > now }
        if isClock {
            let daytime = future.first {
                (7...22).contains(calendar.component(.hour, from: $0))
            }
            return daytime ?? future.first
        }
        return future.first
    }

    /// `text` without `range` and its joining words, tidied into a title.
    static func title(_ text: String, cutting range: Range<String.Index>) -> String {
        var before = text[..<range.lowerBound].split(whereSeparator: \.isWhitespace).map(String.init)
        var after = text[range.upperBound...].split(whereSeparator: \.isWhitespace).map(String.init)
        if let last = before.last?.lowercased(), ["at", "on", "by"].contains(last) {
            before.removeLast()
        }
        if let first = after.first?.lowercased(), first == "to" {
            after.removeFirst()
        }
        let joined = (before + after).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    /// What follows the trigger, or nil when `text` doesn't start with one.
    private static func body(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for trigger in triggers {
            guard trimmed.prefix(trigger.count).lowercased() == trigger else { continue }
            let rest = trimmed.dropFirst(trigger.count)
            if let last = trigger.last, last.isLetter, let next = rest.first, next.isLetter {
                continue
            }
            return rest.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func validDate(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date? {
        let parts = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: parts) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        return back.year == year && back.month == month && back.day == day ? date : nil
    }
}
