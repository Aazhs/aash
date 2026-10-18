# T36 · Reminder fallback and wording

Phase 4 · Target: AashAI · Risk: low · Detail: full

## Goal

`ReminderFallback` holds the Gemini request for a reminder the local parser couldn't read (the
schema, the system text and the prompt) and decodes the reply into a `ReminderSuggestion`.
`ChatPrompts` gains the reminder lines the chat shows: "Added: Call mum · today 7:00 PM", the Undo
line and two error lines. Pure code with tests; T22 wires it in.

## Read first

- `docs/reminders.md#gemini-fallback-schema-t22`
- `docs/ai.md#observed-format` (`json-reply.json`)
- `Sources/AashAI/ChatPrompts.swift`, `Tests/AashAITests/ChatWordingTests.swift`,
  `Tests/AashAITests/GeminiProviderTests.swift` (its `Fixture` helper)

## Files

- create `Sources/AashAI/ReminderFallback.swift`
- edit `Sources/AashAI/ChatPrompts.swift`: add `import Foundation` and the reminder lines
- create `Tests/AashAITests/ReminderFallbackTests.swift`
- edit `Tests/AashAITests/ChatWordingTests.swift`: four tests for the new lines

## Interfaces

```swift
// ReminderFallback.swift
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
    public static let schema: Data
    /// The system instruction for the request.
    public static let system: String
    /// The single user message: the current local time, then the user's text.
    public static func prompt(_ text: String, now: Date, calendar: Calendar) -> String
    /// The reminder in Gemini's JSON reply, or nil when it isn't one. Throws
    /// `ChatError.badResponse` when the JSON can't be read.
    public static func suggestion(from data: Data, calendar: Calendar) throws -> ReminderSuggestion?
}

// ChatPrompts.swift, added inside `enum ChatPrompts`
/// The line after a reminder is added: "Added: Call mum · today 7:00 PM".
public static func reminderAdded(title: String, due: Date, now: Date, calendar: Calendar) -> String
/// The line after Undo: "Removed: Call mum."
public static func reminderRemoved(title: String) -> String
/// Shown when Reminders access is off.
public static let remindersNoAccess = "Aash can't use Reminders yet. Allow it in System Settings → Privacy & Security → Reminders."
/// Shown when a reminder couldn't be saved.
public static let reminderFailed = "Couldn't add that to Reminders. Try again?"
/// Shown when Undo couldn't remove the reminder.
public static let reminderUndoFailed = "Couldn't remove it. You can delete it in Reminders."
```

## Steps

1. `schema`: `Data(#"{"type":"object","properties":{"isReminder":{"type":"boolean"},"title":{"type":"string"},"due":{"type":"string","description":"ISO 8601 local date-time, e.g. 2026-10-18T18:00"}},"required":["isReminder"]}"#.utf8)`.
   `Data` is `Sendable`, so a `static let` is fine.
2. `system`, exactly:
   `"Read one chat message. isReminder is true only when it asks to be reminded of something. title: the thing to do in a few words, first letter capitalised, without the date or time. due: the local date and time it is due, as yyyy-MM-ddTHH:mm. With a day but no time, use 09:00. With a time but no day, use the next time it comes."`
3. `prompt`: `"Now: \(stamp)\nMessage: \(text)"`, where `stamp` comes from a `DateFormatter` made
   **inside the function**: `locale = Locale(identifier: "en_US_POSIX")`, `calendar = calendar`,
   `timeZone = calendar.timeZone`, `dateFormat = "EEEE yyyy-MM-dd HH:mm"`. Example:
   `"Now: Sunday 2026-10-18 10:00\nMessage: remind me to pay the bill on the 25th"`.
4. `suggestion(from:calendar:)`:
   1. Decode with `JSONDecoder` into a private `struct Reply: Decodable { var isReminder: Bool;
      var title: String?; var due: String? }`. A decode error throws
      `ChatError.badResponse("reminder reply")`.
   2. Return nil unless `isReminder` is true, `title` trimmed of whitespace isn't empty, and `due`
      parses. To parse, use a formatter made like step 3, trying `"yyyy-MM-dd'T'HH:mm"` and then
      `"yyyy-MM-dd'T'HH:mm:ss"`.
   3. Return `ReminderSuggestion(title: trimmed title, due: date)`. Don't check whether `due` is in
      the past here; T22 does that.
5. `ChatPrompts`: add `import Foundation` at the top (the file has none yet), then the members above.
   `reminderAdded`:
   - day word: `calendar.isDate(due, inSameDayAs: now)` → `today`; the same day as `now` + 1 day →
     `tomorrow`; otherwise a formatter with `dateFormat = "EEE d MMM"` → `Fri 23 Oct`
   - time: a formatter with `dateFormat = "h:mm a"` → `7:00 PM`
   - both formatters set up as in step 3 (`en_US_POSIX`, `calendar`, `calendar.timeZone`)
   - result: `"Added: \(title) · \(day) \(time)"`. The middle dot is U+00B7 with a space on each side.
   `reminderRemoved`: `"Removed: \(title)."`
6. Write the tests below. Run `./scripts/check.sh --target AashAI` while working (this card runs in
   parallel with T20); finish with it passing. The orchestrator runs the full check and the tests.
   Don't touch `Sources/AashCore` even if the full build breaks there.

## Rules

- AashAI imports only Foundation, Security and os. It can't import AashCore, which is why
  `ReminderSuggestion` is its own type (`docs/architecture.md#targets`).
- `DateFormatter` isn't `Sendable`: make one inside each function, never in a `static let`.
- Swift Testing only. Dates in tests come from components in `Asia/Kolkata`.

## Done when

- [ ] `./scripts/check.sh --target AashAI` passes, and the orchestrator's full `./scripts/check.sh`
  prints `CHECK PASS`
- [ ] In `ReminderFallbackTests.swift` (IST calendar; `now` = 18 Oct 2026 10:00 IST):
  - `schemaRequiresIsReminder`: `JSONSerialization` of `schema` has `required == ["isReminder"]`
    and property keys `{isReminder, title, due}`
  - `promptStatesNowAndMessage`: `prompt("remind me to pay the bill on the 25th", now:, calendar:)`
    == `"Now: Sunday 2026-10-18 10:00\nMessage: remind me to pay the bill on the 25th"`
  - `fixtureReplyIsCallMum`: `Data(try GeminiWire.replyText(<json-reply.json>).utf8)` →
    `suggestion` == `ReminderSuggestion(title: "Call mum", due: 19 Oct 2026 19:00 IST)`. Load the
    fixture with a private helper copied from `GeminiProviderTests.Fixture`.
  - `notAReminderIsNil`: `{"isReminder": false}` → nil
  - `missingDueIsNil`: `{"isReminder": true, "title": "Call mum"}` → nil
  - `blankTitleIsNil`: `{"isReminder": true, "title": "  ", "due": "2026-10-19T19:00"}` → nil
  - `secondsAreAccepted`: `{"isReminder": true, "title": "Call mum", "due": "2026-10-19T19:00:00"}` →
    19 Oct 19:00
  - `badJSONThrows`: `Data("nope".utf8)` → `#expect(throws: ChatError.self)`
- [ ] In `ChatWordingTests.swift`, with `now` = 18 Oct 2026 10:00 IST:
  - `reminderAddedToday`: Call mum, 18 Oct 19:00 → `"Added: Call mum · today 7:00 PM"`
  - `reminderAddedTomorrow`: Call mum, 19 Oct 09:00 → `"Added: Call mum · tomorrow 9:00 AM"`
  - `reminderAddedLater`: Pay rent, 23 Oct 09:00 → `"Added: Pay rent · Fri 23 Oct 9:00 AM"`
  - `reminderRemovedLine`: `reminderRemoved(title: "Pay rent")` → `"Removed: Pay rent."`

## Out of scope

- Calling Gemini, the chat UI, Reminders: T22.
- Localised date formats. The app is English-only, so the line uses a fixed English format.

## Notes

- `GeminiWire.replyText` is internal; the tests reach it with `@testable import AashAI`.
- `en_US_POSIX` with `"h:mm a"` gives `AM`/`PM` in capitals, whatever the Mac's own locale.
