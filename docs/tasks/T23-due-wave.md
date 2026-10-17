# T23 · Wave before due

Phase 4 · Target: Aash · Risk: low · Detail: outline

## Goal

The buddy waves 5 seconds before each reminder is due, using the engine's `reminderAt` (no timer
of its own). The right-click menu shows how many reminders are due today.

## Read first

- `docs/reminders.md#the-wave-t23`, `#morning-count`
- `docs/behaviour.md` (the `reminderAt` event)

## Files (expected)

- create `Sources/Aash/ReminderScheduler.swift`
- edit `Sources/Aash/AppDelegate.swift`, `BuddyController.swift` (tell the scheduler when a reminder
  wave starts), `AppMenu.swift` (the count line)

## Done when (to be detailed by /plan-phase 4)

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Manual: a reminder due in 2 minutes → the buddy waves about 5 s before the system alert; with
  two reminders, the second one waves too; the menu shows "2 reminders today"
- [ ] `./scripts/measure.sh 60 idle` still passes
