import Foundation

extension ChatError {
    /// The one line the popover shows for this error. `timeZone` and `locale` format the quota reset time.
    public func userMessage(timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        switch self {
        case .noKey:
            return "Add your free Gemini key in Settings to chat."
        case .badKey:
            return "Gemini didn't accept the key. Check it in Settings."
        case .quota(let resetsAt):
            guard let resetsAt else {
                return "Free Gemini limit reached for today. Try again later."
            }
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: locale)
            return "Free Gemini limit reached for today. It resets at \(formatter.string(from: resetsAt))."
        case .offline:
            return "You're offline. Chat needs the internet; everything else still works."
        case .timedOut:
            return "Gemini took too long. Try again?"
        case .server, .badResponse:
            // The server's message stays in the log; the user never sees it.
            return "Something went wrong talking to Gemini."
        }
    }
}
