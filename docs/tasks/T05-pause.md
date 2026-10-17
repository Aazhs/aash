# T05 · Pause when nobody's looking

Phase 1 · Target: Aash · Risk: medium · Detail: full

## Goal

When the screen sleeps, the Mac locks, Low Power Mode turns on or the status item can't be seen,
the buddy gets `paused(true)` and the clock stops completely. It resumes when all of those clear.

## Read first

- `docs/menubar.md#hidden-bar-full-screen-lock`
- `docs/patterns.md#observers` and `#logging`
- `docs/behaviour.md#events` (rows `paused(true)` and `paused(false)`)
- `Sources/Aash/AppDelegate.swift`, `Sources/Aash/StatusItemController.swift` (T04)

## Files

- create `Sources/Aash/SystemEvents.swift`
- edit `Sources/Aash/AppDelegate.swift`: create, start and keep a `SystemEvents`, and forward its
  changes to the buddy

## Interfaces

```swift
// SystemEvents.swift
import AppKit

/// Watches for the Mac becoming unwatched: screen asleep, locked, Low Power Mode, buddy hidden.
@MainActor
final class SystemEvents {
    /// Why the buddy is paused right now.
    enum Reason: String, CaseIterable {
        case screenAsleep, locked, lowPower, hidden
    }
    /// Called with the new value whenever `isPaused` changes.
    var onPausedChange: ((Bool) -> Void)?
    /// The reasons that currently apply.
    private(set) var reasons: Set<Reason> = []
    /// True while any reason applies.
    var isPaused: Bool { get }
    /// `statusWindow` returns the status item's window when asked; it may be nil early on.
    init(statusWindow: @escaping @MainActor () -> NSWindow?)
    /// Starts observing, and reads Low Power Mode's current state.
    func start()
    /// Removes every observer.
    func stop()
}
```

## Steps

1. Store observer tokens together with the centre they came from, as
   `[(NotificationCenter, NSObjectProtocol)]`, so `stop()` removes each from the right centre.
2. A private `set(_ reason: Reason, _ on: Bool)`: update `reasons`; if `isPaused` changed, call
   `onPausedChange(isPaused)`. Log every reason change at `.debug` (category `System`), e.g.
   `"paused reason lowPower: on"`.
3. In `start()`, observe, all with `queue: .main`, `[weak self]` and `MainActor.assumeIsolated`
   (`patterns.md#observers`):
   - `NSWorkspace.shared.notificationCenter`: `NSWorkspace.screensDidSleepNotification` →
     `.screenAsleep` on; `screensDidWakeNotification` → off.
   - `DistributedNotificationCenter.default()`: `Notification.Name("com.apple.screenIsLocked")` →
     `.locked` on; `Notification.Name("com.apple.screenIsUnlocked")` → off.
   - `NotificationCenter.default`: `.NSProcessInfoPowerStateDidChange` → `.lowPower` set to
     `ProcessInfo.processInfo.isLowPowerModeEnabled`.
   - `NotificationCenter.default`: `NSWindow.didChangeOcclusionStateNotification` with
     `object: statusWindow()` → `.hidden` set to `!window.occlusionState.contains(.visible)`.
     If `statusWindow()` is nil, log it at `.error` and skip this observer.
   - Finally call `set(.lowPower, ProcessInfo.processInfo.isLowPowerModeEnabled)`. Don't set
     `.hidden` at start: treat unknown as visible.
4. `AppDelegate`: after `buddy.start()`, create
   `SystemEvents(statusWindow: { [weak item] in item?.window })`, set
   `onPausedChange = { [weak buddy] paused in buddy?.handle(.paused(paused)) }`, call `start()`,
   and keep a strong reference. Call `stop()` in `applicationWillTerminate`.

## Rules

- No polling: notifications only (`docs/performance.md`, rule 7).
- `reasons` is a set, so two reasons ending at different times resume correctly: lock, then Low
  Power on, then unlock → still paused.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `stop()` removes every observer it added (check each token is removed from its own centre)

## Manual check

1. Run `./scripts/run.sh`.
2. Ask the user to turn on Low Power Mode (Control Centre → Battery, or System Settings → Battery),
   wait 10 seconds, turn it off, then open any app in full screen for 5 seconds (green window
   button) and leave full screen.
3. Run `log show --last 2m --predicate 'subsystem == "me.aarshj.aash" AND category == "System"' --info --debug`.
4. Ask: "While Low Power Mode was on, did the buddy stop blinking, and did it start again
   afterwards?" Include the `paused reason` lines from the log in the question.
5. If no `hidden` lines appeared during full screen, occlusion doesn't fire for status items on
   this macOS. Add one line saying so, with the date, under
   `docs/menubar.md#hidden-bar-full-screen-lock`. Low Power and lock still work; nothing else to do.

## Out of scope

- Night: already handled inside the engine.
- Anything about walking: the engine snaps home on pause.

## Notes

- `DistributedNotificationCenter` is a subclass of `NotificationCenter`, so the same
  `addObserver(forName:object:queue:using:)` call and removal work.
- `NSWindow.occlusionState` is an option set; `.visible` means at least part of the window can be
  seen.
