# T21 · Reminders store

Phase 4 · Target: Aash · Risk: medium · Detail: outline

## Goal

`RemindersService` asks for Reminders access when first needed, adds a reminder with a due date and
an alarm, removes one (for Undo), lists incomplete reminders due in a date range, and reports
changes.

## Read first

- `docs/reminders.md#eventkit-t21`
- `docs/patterns.md#observers`
- `docs/architecture.md#threading` (no blocking EventKit calls on the main thread)

## Files (expected)

- create `Sources/Aash/RemindersService.swift`
- edit `Resources/Info.plist` (`NSRemindersFullAccessUsageDescription`)

## Sketch

```swift
struct ReminderInfo: Equatable, Sendable { let id: String; let title: String; let due: Date }
@MainActor final class RemindersService {
    var onChange: (() -> Void)?
    func requestAccess() async -> Bool
    func add(title: String, due: Date) async throws -> String      // returns the identifier
    func remove(id: String) async throws
    func incomplete(dueFrom: Date, to: Date) async -> [ReminderInfo]
}
```

## Done when (to be detailed by /plan-phase 4)

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Manual: a temporary debug menu item adds "Aash test" due in 2 minutes; it appears in Reminders
  on the Mac (and the iPhone), alerts on time, and is removed again by the second click. The debug
  item is removed before the card is done.
