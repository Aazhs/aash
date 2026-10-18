import Foundation

/// A reminder Gemini read from a message.
public struct ReminderSuggestion: Equatable, Sendable {
    /// What to do.
    public var title: String
    /// When it's due.
    public var due: Date

    /// Creates a suggestion.
    public init(title: String, due: Date) {
        self.title = title
        self.due = due
    }
}

/// The Gemini request that reads a reminder the local parser couldn't (docs/reminders.md).
public enum ReminderFallback {
    /// The JSON Schema the reply must match.
    public static let schema = Data(#"{"type":"object","properties":{"isReminder":{"type":"boolean"},"title":{"type":"string"},"due":{"type":"string","description":"ISO 8601 local date-time, e.g. 2026-10-18T18:00"}},"required":["isReminder"]}"#.utf8)

    /// The system instruction for the request.
    public static let system = "Read one chat message. isReminder is true only when it asks to be reminded of something. title: the thing to do in a few words, first letter capitalised, without the date or time. due: the local date and time it is due, as yyyy-MM-ddTHH:mm. With a day but no time, use 09:00. With a time but no day, use the next time it comes."

    private struct Reply: Decodable {
        var isReminder: Bool
        var title: String?
        var due: String?
    }

    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }

    /// The single user message: the current local time, then the user's text.
    public static func prompt(_ text: String, now: Date, calendar: Calendar) -> String {
        let stamp = formatter("EEEE yyyy-MM-dd HH:mm", calendar: calendar).string(from: now)
        return "Now: \(stamp)\nMessage: \(text)"
    }

    /// The reminder in Gemini's JSON reply, or nil when it isn't one. Throws
    /// `ChatError.badResponse` when the JSON can't be read.
    public static func suggestion(from data: Data, calendar: Calendar) throws -> ReminderSuggestion? {
        let reply: Reply
        do {
            reply = try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            throw ChatError.badResponse("reminder reply")
        }
        guard reply.isReminder,
              let title = reply.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
              let dueText = reply.due else { return nil }
        for format in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss"] {
            if let date = formatter(format, calendar: calendar).date(from: dueText) {
                return ReminderSuggestion(title: title, due: date)
            }
        }
        return nil
    }
}
