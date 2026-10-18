import Foundation

/// The fixed wording of the chat requests.
public enum ChatPrompts {
    /// The buddy's voice, sent with every chat request.
    public static let system = "You are Aash, a small pixel buddy who lives in the user's macOS menu bar. "
        + "Be warm and brief: at most four short sentences unless asked for more. "
        + "Plain text only: no headings, tables or markdown. "
        + "If asked to do something on the Mac, say what the user can do instead."

    /// The most clipboard characters sent in one request.
    public static let clipboardLimit = 20_000

    /// A one-click action on the clipboard text.
    public enum ClipboardAction: CaseIterable, Sendable {
        case summarise, rewrite, explain

        /// The button title: "Summarise", "Rewrite", "Explain".
        public var title: String {
            switch self {
            case .summarise: "Summarise"
            case .rewrite: "Rewrite"
            case .explain: "Explain"
            }
        }

        /// The one-line instruction sent before the text.
        public var instruction: String {
            switch self {
            case .summarise: "Summarise this in three short bullet points."
            case .rewrite: "Rewrite this to be clear and friendly; keep the meaning."
            case .explain: "Explain this simply."
            }
        }
    }

    /// The single user message for a clipboard action: the instruction, a blank line, then the text cut to `clipboardLimit` characters.
    public static func clipboardMessage(_ action: ClipboardAction, text: String) -> String {
        // `prefix` counts Characters, so the cut never splits an emoji.
        "\(action.instruction)\n\n\(String(text.prefix(clipboardLimit)))"
    }

    /// The line after a reminder is added: "Added: Call mum · today 7:00 PM".
    public static func reminderAdded(title: String, due: Date, now: Date, calendar: Calendar) -> String {
        func formatter(_ format: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format
            return formatter
        }
        let day: String
        if calendar.isDate(due, inSameDayAs: now) {
            day = "today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(due, inSameDayAs: tomorrow) {
            day = "tomorrow"
        } else {
            day = formatter("EEE d MMM").string(from: due)
        }
        return "Added: \(title) \u{00B7} \(day) \(formatter("h:mm a").string(from: due))"
    }

    /// The line after Undo: "Removed: Call mum."
    public static func reminderRemoved(title: String) -> String {
        "Removed: \(title)."
    }

    /// Shown when Reminders access is off.
    public static let remindersNoAccess = "Aash can't use Reminders yet. Allow it in System Settings → Privacy & Security → Reminders."
    /// Shown when a reminder couldn't be saved.
    public static let reminderFailed = "Couldn't add that to Reminders. Try again?"
    /// Shown when Undo couldn't remove the reminder.
    public static let reminderUndoFailed = "Couldn't remove it. You can delete it in Reminders."
}
