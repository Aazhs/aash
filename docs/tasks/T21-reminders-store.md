# T21 · Reminders store

Phase 4 · Target: Aash · Risk: medium · Detail: full

## Goal

`RemindersService` is the app's only way into Apple Reminders. It asks for access the first time
a reminder is added (never at launch), adds a reminder with a due date and an alarm, removes one
(for Undo), lists incomplete reminders due in a date range, and reports changes. Nothing calls it
yet: T22 creates the instance and T23 reads from it.

## Read first

- `docs/reminders.md#eventkit-t21`
- `docs/patterns.md#observers`, `#logging`
- `docs/architecture.md#threading`

## Files

- create `Sources/Aash/RemindersService.swift`
- edit `Resources/Info.plist`: add `NSRemindersFullAccessUsageDescription`

## Interfaces

```swift
import EventKit
import Foundation
import os

/// A reminder read from Apple Reminders.
struct ReminderInfo: Equatable, Sendable {
    /// `EKReminder.calendarItemIdentifier`.
    let id: String
    let title: String
    let due: Date
    /// False for a reminder due on a day with no time set.
    let hasTime: Bool
}

/// Why a Reminders call failed.
enum RemindersError: Error, Equatable {
    /// The user hasn't given full access to Reminders.
    case noAccess
}

/// Adds, removes and reads Apple Reminders through EventKit (docs/reminders.md#eventkit-t21).
@MainActor
final class RemindersService {
    /// Called after the Reminders database changes, including this app's own adds and removes.
    var onChange: (() -> Void)?
    /// True once the user has given full access.
    static var hasAccess: Bool { get }
    /// Asks for full access the first time it's needed; true when access is granted.
    func requestAccess() async -> Bool
    /// Adds a reminder due at `due` with an alarm at the same moment; returns its identifier.
    /// Throws `RemindersError.noAccess` without access, or EventKit's error if saving fails.
    func add(title: String, due: Date) async throws -> String
    /// Removes the reminder with `id`. Does nothing if it's already gone.
    func remove(id: String) throws
    /// Incomplete reminders due in `from..<to`, soonest first. Empty without access; never asks for it.
    func incomplete(dueFrom from: Date, to: Date) async -> [ReminderInfo]
}
```

## Steps

1. `Info.plist`: add, after `LSUIElement`'s `<true/>`:
   ```xml
   	<key>NSRemindersFullAccessUsageDescription</key>
   	<string>Aash adds the reminders you type in its chat and waves when one is due.</string>
   ```
2. File header: `private let log = Logger(subsystem: "me.aarshj.aash", category: "Reminders")`.
3. **The store.** `private var store: EKEventStore?` and `private var token: NSObjectProtocol?`.
   A private `func eventStore() -> EKEventStore` returns `store` if set. Otherwise it creates the
   one `EKEventStore()`, keeps it, and observes it, as in `docs/patterns.md#observers`:
   ```swift
   token = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: made, queue: .main) { [weak self] _ in
       MainActor.assumeIsolated { self?.onChange?() }
   }
   ```
   Only `requestAccess`, `add`, `remove` and `incomplete` (with access) call `eventStore()`, so a
   launch without access creates no store.
4. `hasAccess`: `EKEventStore.authorizationStatus(for: .reminder) == .fullAccess`.
5. `requestAccess()`:
   - `hasAccess` → true
   - status `.notDetermined` → `try await eventStore().requestFullAccessToReminders()`. If that
     throws, log `.error` with `error.localizedDescription` (public) and return false.
   - anything else (`.denied`, `.restricted`, `.writeOnly`) → false, without asking
6. `add(title:due:)`:
   1. `guard await requestAccess() else { throw RemindersError.noAccess }`
   2. `let store = eventStore()`, `let reminder = EKReminder(eventStore: store)`; `title`;
      `calendar = store.defaultCalendarForNewReminders()`.
   3. `var parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)`;
      `parts.timeZone = TimeZone.current`; `reminder.dueDateComponents = parts`.
   4. `reminder.addAlarm(EKAlarm(absoluteDate: due))`.
   5. `try store.save(reminder, commit: true)`, then `log.debug("added reminder")` (no title:
      it's the user's text), then `onChange?()`, then return `reminder.calendarItemIdentifier`.
7. `remove(id:)`: if `!Self.hasAccess`, throw `.noAccess`.
   `let store = eventStore()`;
   `guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }`,
   then `try store.remove(reminder, commit: true)` and `onChange?()`.
8. `incomplete(dueFrom:to:)`: `guard Self.hasAccess else { return [] }`. Then exactly this, which
   compiles cleanly in Swift 6 on this Mac. It was probed on 19 Oct:
   ```swift
   let store = eventStore()
   let predicate = store.predicateForIncompleteReminders(withDueDateStarting: from, ending: to, calendars: nil)
   let found = await withCheckedContinuation { continuation in
       Self.fetch(store, predicate) { continuation.resume(returning: $0) }
   }
   return found.filter { $0.due >= from && $0.due < to }.sorted { $0.due < $1.due }
   ```
   with
   ```swift
   /// Nonisolated so EventKit's background completion isn't treated as main-actor code.
   nonisolated private static func fetch(_ store: EKEventStore, _ predicate: NSPredicate,
                                         done: @escaping @Sendable ([ReminderInfo]) -> Void) {
       store.fetchReminders(matching: predicate) { reminders in
           done((reminders ?? []).compactMap { info($0) })
       }
   }

   nonisolated private static func info(_ reminder: EKReminder) -> ReminderInfo? {
       guard let parts = reminder.dueDateComponents, let due = Calendar.current.date(from: parts) else { return nil }
       return ReminderInfo(id: reminder.calendarItemIdentifier, title: reminder.title ?? "",
                           due: due, hasTime: parts.hour != nil)
   }
   ```
9. `./scripts/check.sh`.

## Rules

- Only `Sources/Aash` may import EventKit (CLAUDE.md, rule 3). `@MainActor` class; `ReminderInfo`
  is a `Sendable` struct and no `EKReminder` leaves `fetch` (rule 6).
- No polling and no timer: changes come from `.EKEventStoreChanged` (CLAUDE.md, rule 5).
- Never ask for access at launch or from `incomplete` (`docs/reminders.md#eventkit-t21`).
- A single `save` or `remove` runs on the main actor. That's accepted: it's one local item, and
  EventKit has no async version (`docs/decisions.md`, 19 Oct). Fetching and asking for access are
  async.
- Never log a reminder's title.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] No tests: the app target has none
- [ ] `grep -rn "EKEventStore()" Sources` finds one line, in `RemindersService.swift`
- [ ] `plutil -extract NSRemindersFullAccessUsageDescription raw Resources/Info.plist` prints the string above

## Out of scope

- Any caller: the chat (T22), the wave and the menu count (T23). There's no manual check here.
  T22's check covers the permission prompt, the alarm and Undo.
- A debug menu item. The outline had one, but it would have to be removed before the manual
  check could use it, so T22 checks the service through the chat instead.
- Choosing a Reminders list, recurring reminders, editing reminders.

## Notes

- `requestFullAccessToReminders()` is the macOS 14 API. The older `requestAccess(to:)` is
  deprecated and needs `NSRemindersUsageDescription`, which the app doesn't have.
- `EKEventStoreChanged` is documented as posted for changes from other processes and for saves
  through your own store. `onChange` is also called directly after `add` and `remove`, so callers
  don't depend on that. A second refresh costs one fetch.
- If `defaultCalendarForNewReminders()` is nil (no Reminders list exists), `save` throws. Let it.
- Unconfirmed: right after access is first granted, a store made before the grant may not see
  the lists yet. If T22's first add fails with "Couldn't add…" and a second try works, call
  `store.reset()` after a successful `requestFullAccessToReminders()`. Don't add it in advance.
