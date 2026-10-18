# T23 · Wave before due

Phase 4 · Target: Aash · Risk: low · Detail: full

## Goal

The buddy waves 5 seconds before each reminder is due. `ReminderScheduler` tells the engine the
next due time with `reminderAt`, and the engine folds it into its one clock, so there's no new
timer. The right-click menu shows how many reminders are due today, counted from the scheduler's
list at the moment the menu opens.

## Read first

- `docs/reminders.md#the-wave-t23`, `#morning-count`
- `docs/behaviour.md`: the `reminderAt` event and step 0 of "Ticks"
- `Sources/Aash/RemindersService.swift` (T21): `incomplete(dueFrom:to:)`, `ReminderInfo`, `onChange`
- `Sources/Aash/AppDelegate.swift`, `BuddyController.swift`, `AppMenu.swift`

## Files

- create `Sources/Aash/ReminderScheduler.swift`
- edit `Sources/Aash/BuddyController.swift`: `onReminderWave`
- edit `Sources/Aash/AppMenu.swift`: the count line
- edit `Sources/Aash/AppDelegate.swift`: create the scheduler and wire its four refresh triggers

## Interfaces

```swift
// ReminderScheduler.swift
import AashCore
import Foundation
import os

/// Tells the engine when the next reminder is due; keeps no timer (docs/reminders.md#the-wave-t23).
@MainActor
final class ReminderScheduler {
    /// How many days ahead each refresh reads.
    static let horizonDays = 8
    /// `send` delivers `reminderAt` to the buddy.
    init(reminders: RemindersService, send: @escaping (BuddyEvent) -> Void, calendar: Calendar = .current)
    /// Re-reads the reminders and sends `reminderAt` for the next one. Cancels a refresh still running.
    func refresh()
    /// Incomplete reminders due on `now`'s day, counted from the last refresh.
    func countToday(now: Date = Date()) -> Int
}

// BuddyController, new property
/// Called each time the buddy starts a reminder wave.
var onReminderWave: (() -> Void)?

// AppMenu: the init gains a last parameter
remindersToday: @escaping () -> Int
```

## Steps

1. **`ReminderScheduler`** (log category `Reminders`). It stores `reminders`, `send`, `calendar`,
   `private var task: Task<Void, Never>?` and `private var known: [ReminderInfo] = []`.
   1. `refresh()`:
      ```swift
      task?.cancel()
      task = Task { @MainActor [weak self] in
          guard let self else { return }
          let start = self.calendar.startOfDay(for: Date())
          let end = self.calendar.date(byAdding: .day, value: Self.horizonDays, to: start) ?? start
          let found = await self.reminders.incomplete(dueFrom: start, to: end)
          guard !Task.isCancelled else { return }
          self.known = found
          let after = Date().addingTimeInterval(BehaviourConfig.standard.waveLead)
          let next = found.first { $0.hasTime && $0.due > after }
          self.send(.reminderAt(next?.due))
      }
      ```
      Then log `.debug` with the number of reminders found and the seconds until `next` (both
      public). Don't log titles.
      `due > now + waveLead` matters: when the wave for a reminder starts, that reminder is still
      5 s from due. Without the lead it would be picked again, its wave time would be in the past,
      and the engine would ignore it, so the following reminder would never be scheduled.
   2. `countToday(now:)`: `start = calendar.startOfDay(for: now)`, `end` = start + 1 day.
      Return `known.filter { $0.due >= start && $0.due < end }.count`. This includes reminders
      already past today and reminders with no time.
2. **`BuddyController`:** add `onReminderWave`. In `handle(_:)`, inside the existing
   `if engine.activity != lastActivity { … }` block, after the log line, add
   `if lastActivity == .waving { onReminderWave?() }`. Only reminders make the buddy wave.
3. **`AppMenu`:**
   1. Add `private let todayItem: NSMenuItem`, `private let todaySeparator: NSMenuItem` and
      `private let remindersToday: () -> Int`.
   2. In `init`: `todayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")` with
      `isEnabled = false` (`autoenablesItems` is already false) and `todaySeparator = .separator()`.
      Add both **first**, before `chatItem`.
   3. In `menuNeedsUpdate`: `let count = remindersToday()`. Set `todayItem.title` to
      `count == 1 ? "1 reminder today" : "\(count) reminders today"`. Set `todayItem.isHidden` and
      `todaySeparator.isHidden` to `count == 0`.
4. **`AppDelegate`:**
   1. `private var scheduler: ReminderScheduler?`.
   2. Right after `self.reminders = reminders` (added by T22):
      ```swift
      let scheduler = ReminderScheduler(reminders: reminders, send: { [weak controller] in controller?.handle($0) })
      self.scheduler = scheduler
      reminders.onChange = { [weak scheduler] in scheduler?.refresh() }
      controller.onReminderWave = { [weak scheduler] in scheduler?.refresh() }
      ```
   3. Pass `remindersToday: { [weak scheduler] in scheduler?.countToday() ?? 0 }` to `AppMenu`.
   4. Replace the `events.onPausedChange` line with:
      ```swift
      events.onPausedChange = { [weak controller, weak scheduler] paused in
          controller?.handle(.paused(paused))
          if !paused { scheduler?.refresh() }   // a reminder may have been due while paused
      }
      ```
      The engine must resume first: resuming drops a wave time that passed while paused.
   5. Call `scheduler.refresh()` once, after `events.start()`. This is the launch refresh.
5. `./scripts/check.sh`.

## Rules

- No timer, no `asyncAfter`, no polling. The four refresh triggers are launch, `onChange`, resume
  and `onReminderWave` (CLAUDE.md, rule 5; `docs/reminders.md#the-wave-t23`).
- No fetch when the menu opens. The count comes from `known` at once (`docs/decisions.md`, 19 Oct).
- Never ask for Reminders access here. `incomplete` returns `[]` without access, and then
  `reminderAt(nil)` is sent, which is harmless.
- `@MainActor`, `[weak …]` captures in every stored closure.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `grep -rn "Timer(" Sources/Aash` still finds only `AnimationClock.swift`
- [ ] `grep -rn "RemindersService()" Sources` still finds one line

## Manual check

The orchestrator runs `./scripts/run.sh`, asks the user to do the steps below, then runs
`./scripts/measure.sh 60 idle` and includes its line. It asks: "Did the buddy wave before each
alert, and does the menu show the right count?" The measure line must say `pass`.

1. In the chat, add two reminders 1 minute apart, about 2 and 3 minutes from now, for example
   `remind me to wave test one at 6:42 pm` and `remind me to wave test two at 6:43 pm`.
2. Right-click the buddy: the menu's top line says `2 reminders today` (more if others are due
   today).
3. About 5 s before each Reminders alert, the buddy waves for about 6 s. It waves for the second
   one too.
4. In the Reminders app, add a reminder due in 2 minutes and wait: the buddy waves for it as well.
5. Mark the test reminders done. Right-click again: the count is lower, or the line is gone.

## Out of scope

- A wave for reminders more than `horizonDays` ahead before the next refresh. The screen sleeps
  at least daily, and resuming refreshes.
- Notifications of our own, sounds, a list of reminders in the menu.

## Notes

- Two reminders due within the same few seconds get one wave. That's fine.
- `send` goes through `BuddyController.handle`. `reminderAt` while paused or waving is stored,
  not acted on (`docs/behaviour.md#events`).
- Creating the `EKEventStore` at launch, when access was given earlier, costs some memory. The
  measure line shows whether it's still under 30 MB. If it isn't, report it; don't change the design.
