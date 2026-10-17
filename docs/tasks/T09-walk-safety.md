# T09 · Walk safety

Phase 2 · Target: Aash · Risk: medium · Detail: full

## Goal

Stretch walks can't cause trouble: they don't start when the bar is too crowded or the item is off
screen, they're shortened to fit, and they end cleanly when screens change.

## Read first

- `docs/menubar.md#stretch-walk` and `#what-macos-27-does`
- `docs/behaviour.md#events` (the `walkArea` row)
- `Sources/Aash/WalkStage.swift`, `StretchStage.swift`, `BuddyController.swift`, `AppMenu.swift` (T08)

## Files

- edit `Sources/Aash/WalkStage.swift`: add `onRoomChanged`
- edit `Sources/Aash/StretchStage.swift`: room check, screen-change observer
- edit `Sources/Aash/BuddyController.swift`: forward `onRoomChanged`; expose `isWalking`
- edit `Sources/Aash/AppMenu.swift`: disable "Walk now" while a walk is on

## Interfaces

```swift
// WalkStage: add
/// Set by BuddyController. Call it when the room changes mid-walk; nil means it's gone.
var onRoomChanged: ((ClosedRange<Double>?) -> Void)? { get set }

// BuddyController: add
/// True from asking a stage for room until the walk is over.
var isWalking: Bool { get }

// AppMenu.init: add a parameter
init(settings: AppSettings, isWalking: @escaping () -> Bool,
     onWalkNow: @escaping () -> Void, onWalkingChanged: @escaping (Bool) -> Void)
```

## Steps

1. `StretchStage.prepare()` now checks room first:
   1. `guard let window = statusItem.window, let screen = window.screen else { return nil }`.
   2. The item must be fully on screen: `window.frame.minX >= screen.frame.minX` and
      `window.frame.maxX <= screen.frame.maxX`, else nil.
   3. `limit = screen.frame.minX + screen.frame.width × 0.45`: a walk never widens the item past
      45% of the screen width, which leaves the left side for app menus.
   4. `d = min(distance(), window.frame.minX − limit − 8)`. If `d < 24`, return nil.
   5. Widen by `d` (as in T08) and return `-d ... 0`.
2. While a walk is on (between a non-nil `prepare` and `finish`), observe
   `NSApplication.didChangeScreenParametersNotification` (`patterns.md#observers`). When it fires,
   call `onRoomChanged?(nil)`. Remove the observer in `finish()`.
3. `BuddyController`: in `init`, set `stage.onRoomChanged = { [weak self] area in self?.handle(.walkArea(area)) }`.
   `isWalking` returns the private `walking` flag.
4. `AppMenu`: "Walk now" is enabled only when walking is on and `!isWalking()`.
5. `AppDelegate`: pass `isWalking: { [weak buddy] in buddy?.isWalking ?? false }`.

## Rules

- Observers only while walking; none left behind after `finish()`.
- `finish()` stays safe to call twice.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `finish()` removes the screen-change observer (check the token handling)

## Manual check

1. Run `./scripts/run.sh`.
2. Ask: "Right-click → Walk now, and while it's walking, lock the screen (Control-Command-Q) for
   a few seconds, then unlock. Is the icon back to its normal size, with the buddy home? Then try
   Walk now again: does it still walk normally?"

## Out of scope

- Free walk: T10–T12.

## Notes

- `window.screen` can be nil while the bar is hidden; returning nil (no walk) is correct then.
- The 45% limit is a guess to keep clear of app menus; T12 replaces it with real measurements when
  free walk is on.
