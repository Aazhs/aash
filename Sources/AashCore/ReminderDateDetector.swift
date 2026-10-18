import Foundation

/// Finds the date or time in a reminder phrase (docs/reminders.md#phrase-parsing-t20-t35).
public enum ReminderDateDetector {
    /// The first usable date or time in `text`, or nil when there is none.
    public static func detect(_ text: String) -> DateMatch? {
        detectWithDataDetector(text) ?? detectDelay(text) ?? detectBareHour(text)
    }

    // MARK: NSDataDetector

    private static func detectWithDataDetector(_ text: String) -> DateMatch? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        else { return nil }
        let results = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for result in results {
            guard let date = result.date, result.duration == 0,
                  let range = Range(result.range, in: text) else { continue }
            let matched = text[range].lowercased()
            // The detector works in the Mac's own time zone.
            let parts = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: date)
            let day = day(in: matched, parts: parts)
            let time = time(in: matched, parts: parts)
            if day == .unspecified && time == .unspecified { continue }
            return DateMatch(range: range, day: day, time: time)
        }
        return nil
    }

    private static func day(in matched: String, parts: DateComponents) -> DateMatch.Day {
        let words = matched.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if matched.contains("day after tomorrow") { return .relative(2) }
        if words.contains("tomorrow") { return .relative(1) }
        if words.contains("today") || words.contains("tonight") { return .relative(0) }
        let weekdays: [String: Int] = [
            "sunday": 1, "sun": 1, "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3, "tues": 3, "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5, "thur": 5, "thurs": 5,
            "friday": 6, "fri": 6, "saturday": 7, "sat": 7,
        ]
        for word in words {
            if let number = weekdays[word] { return .weekday(number) }
        }
        let months: Set<String> = [
            "january", "february", "march", "april", "may", "june", "july", "august",
            "september", "october", "november", "december",
            "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "sept", "oct", "nov", "dec",
        ]
        let hasMonth = words.contains(where: { months.contains($0) })
        if hasMonth || matched.contains(/\d{1,2}[\/-]\d{1,2}/),
           let month = parts.month, let day = parts.day {
            // Never take the year from the detector: it picks one relative to the real clock.
            var year: Int?
            if let found = matched.firstMatch(of: /\b(\d{4})\b/) { year = Int(found.1) }
            return .date(year: year, month: month, day: day)
        }
        return .unspecified
    }

    private static func time(in matched: String, parts: DateComponents) -> DateMatch.Time {
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        if matched.contains(/\d\s*(?:a\.m\.|p\.m\.|am\b|pm\b)/) {
            return .exact(hour: hour, minute: minute)
        }
        let words = Set(matched.split(whereSeparator: { !$0.isLetter }).map(String.init))
        let timeWords: Set<String> = ["morning", "afternoon", "evening", "night", "tonight", "noon", "midnight"]
        if !words.isDisjoint(with: timeWords) {
            return .exact(hour: hour, minute: minute)
        }
        var hourText: Substring?
        var minuteText: Substring?
        if let found = matched.firstMatch(of: /(\d{1,2})[:.](\d{2})/) {
            hourText = found.1
            minuteText = found.2
        } else if let found = matched.firstMatch(of: /\bat\s+(\d{1,2})\b/) {
            hourText = found.1
        }
        guard let hourText, let value = Int(hourText) else { return .unspecified }
        if (hourText.count == 2 && hourText.hasPrefix("0")) || value == 0 || (13...23).contains(value) {
            return .exact(hour: hour, minute: minute)
        }
        if (1...12).contains(value) {
            return .clock(hour: value, minute: minuteText.flatMap { Int($0) } ?? 0)
        }
        return .unspecified
    }

    // MARK: Patterns the detector misses

    private static func detectDelay(_ text: String) -> DateMatch? {
        guard let match = text.firstMatch(
            of: /(?i)\bin\s+(\d{1,3}|an|a)\s+(minutes|minute|mins|min|hours|hour|hrs|hr)\b/
        ) else { return nil }
        let word = match.1.lowercased()
        let count = (word == "a" || word == "an") ? 1 : (Int(word) ?? 1)
        let isHour = match.2.lowercased().hasPrefix("h")
        return DateMatch(range: match.range, day: .unspecified,
                         time: .later(minutes: isHour ? count * 60 : count))
    }

    private static func detectBareHour(_ text: String) -> DateMatch? {
        guard let match = text.firstMatch(of: /(?i)\bat\s+(\d{1,2})(?:[:.](\d{2}))?\b/),
              let hour = Int(match.1), (0...23).contains(hour) else { return nil }
        let minute = match.2.flatMap { Int($0) } ?? 0
        guard (0...59).contains(minute) else { return nil }
        let leadingZero = match.1.count == 2 && match.1.hasPrefix("0")
        let time: DateMatch.Time = (1...12).contains(hour) && !leadingZero
            ? .clock(hour: hour, minute: minute)
            : .exact(hour: hour, minute: minute)
        return DateMatch(range: match.range, day: .unspecified, time: time)
    }
}
