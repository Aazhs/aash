# T22 · Reminders from chat

Phase 4 · Target: Aash · Risk: medium · Detail: full

## Goal

Typing a reminder in the chat creates it in Apple Reminders. The local parser goes first, and
Gemini's JSON reply is the fallback for a reminder request it can't read. The chat shows
"Added: Submit the lab report · today 6:00 PM" with an Undo button, and the buddy cheers.
Ordinary messages still get normal replies. The app now owns its one `RemindersService`.

## Read first

- `docs/reminders.md#flow`, `#gemini-fallback-schema-t22`
- `Sources/Aash/ChatViewController.swift`, `ChatPopoverController.swift`, `AppDelegate.swift`
- `Sources/Aash/RemindersService.swift` (T21), `Sources/AashCore/ReminderPhraseParser.swift` (T35),
  `Sources/AashAI/ReminderFallback.swift` and the reminder lines in `ChatPrompts.swift` (T36):
  public API only

## Files

- create `Sources/Aash/ReminderIntent.swift`
- edit `Sources/Aash/ChatViewController.swift`: route reminder requests, show the outcome, Undo
- edit `Sources/Aash/ChatPopoverController.swift`: take a `RemindersService` and build a
  `ReminderIntent` for each popover
- edit `Sources/Aash/AppDelegate.swift`: create and keep the one `RemindersService`

## Interfaces

```swift
// ReminderIntent.swift
import AashAI
import AashCore
import Foundation
import os

/// Turns a chat message into an Apple Reminders item: the local parser first, Gemini as the fallback.
@MainActor
final class ReminderIntent {
    /// What became of a message.
    enum Outcome: Equatable {
        /// Not a reminder: send it to the chat as usual.
        case notReminder
        /// Added to Reminders; `id` is for Undo.
        case added(id: String, title: String, due: Date)
        /// Reminders access is off.
        case noAccess
        /// Saving failed.
        case failed
    }

    init(reminders: RemindersService, provider: any ChatProvider, calendar: Calendar = .current)
    /// Reads `text` and adds the reminder it asks for.
    func handle(_ text: String) async -> Outcome
    /// Removes a reminder this chat added; false if that failed.
    func undo(id: String) -> Bool
}

// ChatViewController: the init gains one parameter, after `provider`
init(provider: any ChatProvider, reminders: ReminderIntent, hasKey: Bool,
     openSettings: @escaping () -> Void, onReply: @escaping () -> Void)

// ChatPopoverController: the init gains one parameter, after `settings`
init(anchor: @escaping () -> NSView?, settings: AppSettings, reminders: RemindersService,
     keychain: KeychainStore = KeychainStore(), openSettings: @escaping () -> Void,
     onEvent: @escaping (BuddyEvent) -> Void)
```

## Steps

1. **`ReminderIntent`** (log category `Reminders`):
   1. `handle(_:)`:
      - `guard ReminderPhraseParser.isReminderRequest(text) else { return .notReminder }`
      - `let now = Date()`. If `ReminderPhraseParser.parse(text, now: now, calendar: calendar)`
        gives a reminder, use its title and due date.
      - Otherwise call the private `fallback(text, now:)`. Use its result only if `due > Date()`.
        Otherwise return `.notReminder`, so a fallback that fails or says "not a reminder" ends
        in a normal chat reply. That reply also shows any key or network error.
      - `let id = try await reminders.add(title:due:)` → `.added(id:title:due:)`.
        `catch RemindersError.noAccess` → `.noAccess`. Any other error: log `.error` with
        `error.localizedDescription` (public) and return `.failed`.
   2. `private func fallback(_ text: String, now: Date) async -> ReminderSuggestion?`:
      `try await provider.json(ReminderFallback.prompt(text, now: now, calendar: calendar),
      system: ReminderFallback.system, schema: ReminderFallback.schema)`, then
      `try ReminderFallback.suggestion(from: data, calendar: calendar)`. On any error, log `.error`
      `"reminder fallback failed"` (no content) and return nil.
   3. `undo(id:)`: `do { try reminders.remove(id: id); return true }`. On an error, log it and
      return false.
2. **`ChatViewController`:**
   1. New stored properties: `private let reminders: ReminderIntent`,
      `private let undoButton = NSButton(title: "Undo", target: nil, action: nil)`,
      `private var reminderTask: Task<Void, Never>?`,
      `private var lastAdded: (id: String, title: String)?`.
   2. `loadView`: set up `undoButton` like `settingsButton` (`.rounded` bezel, target `self`,
      action `#selector(undoClicked(_:))`, hidden). Insert it after `settingsButton` in the stack:
      `[scroll, settingsButton, undoButton, row, input]`.
   3. `cancel()`: also `reminderTask?.cancel()` and `reminderTask = nil`.
   4. `submit(_ text: String, display: String?)`: `display` becomes optional, and the line
      `appendText(display, …)` runs only when it isn't nil. `runClipboardAction` still passes its
      display string.
   5. `send(_:)`: after `input.stringValue = ""`, hide the Undo button (`hideUndo()`, step 7). If
      `!ReminderPhraseParser.isReminderRequest(text)`, call `submit(text, display: text)` as today.
      Otherwise:
      ```swift
      appendText(text, color: .controlAccentColor, separate: true)
      streaming = true
      let intent = reminders
      reminderTask = Task { @MainActor [weak self] in
          let outcome = await intent.handle(text)
          guard !Task.isCancelled else { return }
          self?.finishReminder(outcome, text: text)
      }
      ```
   6. `private func finishReminder(_ outcome: ReminderIntent.Outcome, text: String)`. First set
      `streaming = false` and `reminderTask = nil`, then:
      - `.added(id, title, due)` → `appendText(ChatPrompts.reminderAdded(title:due:now: Date(),
        calendar: .current), color: .labelColor, separate: true)`; `lastAdded = (id, title)`;
        `undoButton.isHidden = false`; `onReply()` (the buddy cheers)
      - `.notReminder` → `submit(text, display: nil)`. The text is already shown.
      - `.noAccess` → `appendText(ChatPrompts.remindersNoAccess, color: .secondaryLabelColor, separate: true)`
      - `.failed` → `appendText(ChatPrompts.reminderFailed, color: .secondaryLabelColor, separate: true)`
      - then `textView.scrollToEndOfDocument(nil)`
   7. `private func hideUndo()`: `undoButton.isHidden = true`; `lastAdded = nil`. Call it from
      `send` and from `runClipboardAction`, once the guard has passed.
   8. `@objc private func undoClicked(_ sender: Any?)`: `guard let added = lastAdded`, then
      `hideUndo()`. `reminders.undo(id: added.id)` true → `ChatPrompts.reminderRemoved(title: added.title)`,
      false → `ChatPrompts.reminderUndoFailed`. Append either in `.secondaryLabelColor` and scroll
      to the end.
   9. Reminder messages don't go into `history`, except through `.notReminder` → `submit`.
3. **`ChatPopoverController`:** store `reminders`. In `show()`, after `provider` is made:
   `let intent = ReminderIntent(reminders: reminders, provider: provider)`, and pass
   `reminders: intent` to `ChatViewController`. The intent is released with the popover.
4. **`AppDelegate`:** add `private var reminders: RemindersService?`. In
   `applicationDidFinishLaunching`, right before `chat = ChatPopoverController(`, add
   `let reminders = RemindersService()` and `self.reminders = reminders`. Pass
   `reminders: reminders` after `settings: settings`. This is the app's only instance: T23
   reuses it.
5. `./scripts/check.sh`.

## Rules

- `@MainActor` everywhere. The task pattern is `docs/patterns.md#streaming` ("Consume it on the
  main actor"). No `DispatchQueue`.
- Gemini is called only for a message that starts with a trigger and that the local parser can't
  read (`docs/ai.md#requests-the-app-makes`). Every other message costs exactly one request, as before.
- No modal alerts: errors are lines in the chat (`docs/architecture.md#errors`).
- Never log message text or reminder titles.
- `ChatViewController.swift` must stay under 300 lines.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `grep -rn "RemindersService()" Sources` finds one line, in `AppDelegate.swift`
- [ ] No tests: the app target has none. The parser and the fallback are covered by T35 and T36.

## Manual check

The orchestrator runs `./scripts/run.sh`, then asks the user to do the steps below in the chat. In
step 1, a time about 3 minutes ahead means one like "6:42 pm". Then it asks: "Did each step do
what it says?"

1. Type `remind me to test Aash at <a time about 3 minutes from now, with am/pm>`. macOS asks for
   Reminders access with "Aash adds the reminders you type in its chat and waves when one is
   due." Allow it. The dialog may close the popover. The reminder is still added, but without the
   "Added" line. Either way, the item is in the Reminders app. Open the chat again. At that time the Reminders alert
   appears on the Mac.
2. `remind me to call the bank tomorrow at 9am` → `Added: Call the bank · tomorrow 9:00 AM` with an
   Undo button, and the buddy raises its arms.
3. `reminder: dentist on Friday` → `Added: Dentist · Fri <date> 9:00 AM`. Click Undo: the chat
   shows `Removed: Dentist.` and the item is gone from Reminders.
4. Only Gemini can read this one: `remind me to pay the bill on the 25th` →
   `Added: Pay the bill · <the 25th> 9:00 AM`, or a similar title.
5. `what's a good name for a cat?` gets a normal reply.
6. Optional, last: turn Aash off in System Settings → Privacy & Security → Reminders, then try
   `remind me to stretch at 8 pm`. The chat says Aash can't use Reminders yet. Turn it back on
   afterwards. If macOS quits the app when the setting changes, run `./scripts/run.sh` again.

Delete the test reminders from step 1 and 2 afterwards.

After the steps, with the chat closed, the orchestrator runs `WARMUP=30 ./scripts/measure.sh 20 idle`
and includes the line. Memory was 33 MB after closing the chat in T19, and the `EKEventStore` adds
to that. Report the number. A result over 35 MB is a problem to raise, not to fix inside this card.

## Out of scope

- The buddy waving before the due time and the menu count: T23.
- Editing a reminder, choosing a list, recurring reminders, reminders without a trigger phrase.
- A clickable link instead of the Undo button.

## Notes

- The first add shows the system's permission dialog. Clicking it can close the `.transient`
  popover, which cancels the task, so that first reminder gets no confirmation line. That's
  accepted (`docs/decisions.md`, 19 Oct). Don't change the popover's behaviour for it.
- If the popover closes while a reminder is being added, the task is cancelled, but EventKit may
  still save it: the reminder then exists with no confirmation shown. That's accepted.
- Reminders need the signed build (`docs/WORKFLOW.md#signing`), otherwise macOS asks again after
  every build.
