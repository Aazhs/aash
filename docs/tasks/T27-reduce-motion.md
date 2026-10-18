# T27 · Respect Reduce Motion

Phase 2 · Target: Aash · Risk: low · Detail: full

## Goal

While System Settings → Accessibility → Display → Reduce Motion is on, the buddy doesn't walk:
no timed walks, no Walk now, no free walk. It still blinks, sleeps, waves and cheers in place.
Turning Reduce Motion off brings walks back at once, without a relaunch.

## Read first

- `docs/patterns.md#observers`
- `Sources/Aash/SystemEvents.swift`, `AppDelegate.swift`, `AppMenu.swift`
- `docs/behaviour.md#events`: `walkingEnabled(_)`

## Files

- edit `Sources/Aash/SystemEvents.swift`: watch Reduce Motion
- edit `Sources/Aash/AppDelegate.swift`: send the engine the effective walking state
- edit `Sources/Aash/AppMenu.swift`: show why walking is off
- edit `docs/menubar.md`: a short "Reduce Motion" section

## Interfaces

```swift
// SystemEvents.swift
/// Called with the new value whenever Reduce Motion changes.
var onReduceMotionChange: ((Bool) -> Void)?
/// True while the user has Reduce Motion on.
private(set) var reduceMotion: Bool

// AppMenu.swift: a new init parameter
reduceMotion: @escaping () -> Bool
```

## Requirements

1. `SystemEvents.start()` reads `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` and
   observes `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` on
   `NSWorkspace.shared.notificationCenter`, using the existing `observe` helper. Call
   `onReduceMotionChange` only when the value changes. Log the change at `.debug` (category `System`).
   Reduce Motion is not a pause reason: don't add it to `Reason`.
2. `AppDelegate` sends the engine `walkingEnabled(settings.walkingEnabled && !events.reduceMotion)`:
   at start, when the menu toggles walking, and when Reduce Motion changes. Make `SystemEvents`
   before `controller.start` so the first value is right.
3. `AppMenu.menuNeedsUpdate`: while Reduce Motion is on, "Walk now", "Walking" and "Walk on the
   Whole Bar" are disabled, and "Walking" reads "Walking (off for Reduce Motion)". The stored
   `walkingEnabled` setting is never changed by Reduce Motion.
4. A walk in progress when Reduce Motion turns on goes home the normal way
   (`walkingEnabled(false)` already does that).

## Steps

1. `SystemEvents`: property, callback, observer.
2. `AppDelegate`: one small private func that computes and sends the effective walking state; call
   it from all three places.
3. `AppMenu`: the new parameter and the menu states.
4. Add the section to `docs/menubar.md`.

## Rules

- No new timer and no polling: the notification is the only signal (CLAUDE.md rule 5).
- No engine change. `AashCore` already handles `walkingEnabled`.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] With Reduce Motion off, behaviour is exactly T12's

## Manual check

1. Run `./scripts/run.sh`.
2. Ask: "Turn on Reduce Motion (System Settings → Accessibility → Display). Right-click the buddy:
   is Walking greyed out and labelled 'off for Reduce Motion'? Turn Reduce Motion off again: does
   Walk now work?"

## Out of scope

- Slowing walks down instead of stopping them.
- Changing blink, wave or cheer animations.

## Notes

- `accessibilityDisplayShouldReduceMotion` is on `NSWorkspace`, not `NSScreen` or `NSApplication`.
