# T32 · Chat wording

Phase 3 · Target: AashAI · Risk: low · Detail: full

## Goal

The words the chat uses live in `AashAI`, where they can be tested: the buddy's system instruction,
the three clipboard actions and how they build a message, and the friendly line for each
`ChatError`. T17 only displays them.

## Read first

- `docs/ai.md#requests-the-app-makes`, `#errors-the-user-sees`, `#the-buddys-voice`
- `Sources/AashAI/ChatProvider.swift` (`ChatError`, T31)
- `docs/patterns.md#tests`

## Files

- create `Sources/AashAI/ChatPrompts.swift`
- create `Sources/AashAI/ChatError+Message.swift`
- create `Tests/AashAITests/ChatWordingTests.swift`

## Interfaces

```swift
// ChatPrompts.swift
/// The fixed wording of the chat requests.
public enum ChatPrompts {
    /// The buddy's voice, sent with every chat request.
    public static let system: String
    /// The most clipboard characters sent in one request.
    public static let clipboardLimit = 20_000

    /// A one-click action on the clipboard text.
    public enum ClipboardAction: CaseIterable, Sendable {
        case summarise, rewrite, explain
        /// The button title: "Summarise", "Rewrite", "Explain".
        public var title: String { get }
        /// The one-line instruction sent before the text.
        public var instruction: String { get }
    }

    /// The single user message for a clipboard action: the instruction, a blank line, then the text cut to `clipboardLimit` characters.
    public static func clipboardMessage(_ action: ClipboardAction, text: String) -> String
}

// ChatError+Message.swift
extension ChatError {
    /// The one line the popover shows for this error. `timeZone` and `locale` format the quota reset time.
    public func userMessage(timeZone: TimeZone = .current, locale: Locale = .current) -> String
}
```

## Steps

1. `ChatPrompts.system` is exactly (one string, sentences joined by single spaces, no newlines):
   `You are Aash, a small pixel buddy who lives in the user's macOS menu bar. Be warm and brief: at most four short sentences unless asked for more. Plain text only: no headings, tables or markdown. If asked to do something on the Mac, say what the user can do instead.`
2. `ClipboardAction.instruction` values, exactly:
   - summarise: `Summarise this in three short bullet points.`
   - rewrite: `Rewrite this to be clear and friendly; keep the meaning.`
   - explain: `Explain this simply.`
   Titles: `Summarise`, `Rewrite`, `Explain`.
3. `clipboardMessage`: `"\(action.instruction)\n\n\(String(text.prefix(clipboardLimit)))"`. `prefix` counts
   `Character`s, so it never splits an emoji.
4. `userMessage`, exactly these lines (curly apostrophes are plain `'` here):
   | Case | Line |
   |---|---|
   | `.noKey` | `Add your free Gemini key in Settings to chat.` |
   | `.badKey` | `Gemini didn't accept the key. Check it in Settings.` |
   | `.quota(resetsAt: date)` | `Free Gemini limit reached for today. It resets at <time>.` |
   | `.quota(resetsAt: nil)` | `Free Gemini limit reached for today. Try again later.` |
   | `.offline` | `You're offline. Chat needs the internet; everything else still works.` |
   | `.timedOut` | `Gemini took too long. Try again?` |
   | `.server`, `.badResponse` | `Something went wrong talking to Gemini.` |
   `<time>`: a `DateFormatter` with `locale`, `timeZone`, and
   `dateFormat = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: locale)`
   (so 24-hour locales show `13:30` and US ones `1:30 PM`).
5. Tests below, with fixed dates built from components and fixed time zones/locales.

## Rules

- Value types and constants only; `Sendable`. No AppKit. No `print`.
- Never put the user's text, or a server message, in a user-facing line (the `server` message goes
  to the log only).

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] Tests (suite `ChatWordingTests`, one `@Test` each):
  - `systemInstructionIsTheDocumentedText`: `ChatPrompts.system` equals the string in step 1
  - `clipboardMessageJoinsInstructionAndText`: `.summarise` with `"Hello"` →
    `"Summarise this in three short bullet points.\n\nHello"`
  - `clipboardTextIsCutToTheLimit`: 25,000 × `"a"` → the message after the blank line has exactly
    20,000 characters
  - `clipboardCutNeverSplitsAnEmoji`: 19,999 × `"a"` followed by `"👩‍👩‍👧"` and more text → the part after the blank
    line ends with the whole `👩‍👩‍👧`
  - `actionTitlesAreStable`: `ClipboardAction.allCases.map(\.title) == ["Summarise", "Rewrite", "Explain"]`
  - `quotaLineShowsLocalResetTime`: `.quota(resetsAt: 2026-10-18 07:00 UTC)`, `Asia/Kolkata`, locale
    `en_GB` → `"Free Gemini limit reached for today. It resets at 12:30."`
  - `quotaWithoutResetTime`: `.quota(resetsAt: nil)` → `"Free Gemini limit reached for today. Try again later."`
  - `otherErrorLines`: `.noKey`, `.badKey`, `.offline`, `.timedOut`, `.server(status: 500, message: "x")`,
    `.badResponse("y")` → the lines in the table
  - `serverMessageIsNotShown`: `.server(status: 500, message: "secret detail")` line does not contain
    `"secret"`

## Out of scope

- Any UI. Sending requests. Translating to other languages.

## Notes

- The reset time is local: the free tier resets at midnight Pacific, which is 12:30 PM or 1:30 PM IST.
