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
}
