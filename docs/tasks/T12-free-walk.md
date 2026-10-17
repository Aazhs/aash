# T12 · Free walk

Phase 2 · Target: Aash · Risk: high · Detail: full

## Goal

With "Walk on the whole bar" turned on and Accessibility allowed, the buddy leaves its icon, passes
hidden behind the other status items, appears in the free part of the menu bar, walks there and
comes back. Without permission, or when the scan looks wrong, the walk falls back to a stretch
walk. This is the one card where the docs can't settle every detail: window level and Spaces
behaviour have to be found by trying. That's why it runs on Opus.

## Read first

- `docs/menubar.md`: all of it, especially `#accessibility-findings` (T10's results)
- `docs/behaviour.md#the-walk-handshake`
- `docs/patterns.md#sprite-layer`, `#observers`
- `Sources/Aash/WalkStage.swift`, `StretchStage.swift`, `MenuBarScanner.swift`,
  `SpriteLayerView.swift`, `BuddyController.swift`, `AppMenu.swift`, `AppSettings.swift`
- `Sources/AashCore/FreeSpace.swift` (T11)

## Files

- create `Sources/Aash/WalkWindow.swift`
- create `Sources/Aash/FreeWalkStage.swift`
- edit `Sources/Aash/AppSettings.swift`: `freeWalkEnabled` (Bool, default false)
- edit `Sources/Aash/AppMenu.swift`: a "Walk on the Whole Bar" toggle under "Walking"
- edit `Sources/Aash/AppDelegate.swift`: use `FreeWalkStage`, which wraps the stretch stage
- edit `Sources/Aash/StatusItemController.swift` only if the home icon needs an "out" state
- edit `docs/menubar.md`: record the window level and collection behaviour you settled on

## Interfaces

```swift
// WalkWindow.swift
/// A sprite-sized, borderless, non-activating panel that shows the buddy above the menu bar.
@MainActor
final class WalkWindow {
    init()
    /// Called when the buddy is clicked while out walking.
    var onClick: (() -> Void)?
    /// Shows the buddy with its left edge at screen x, vertically centred on the menu bar.
    func show(_ frame: SpriteFrame, facingLeft: Bool, screenX: CGFloat, on screen: NSScreen)
    /// Hides the panel. It stays allocated only for the length of one walk.
    func hide()
}

// FreeWalkStage.swift
/// Walks over the free part of the menu bar when allowed; otherwise delegates to the stretch stage.
@MainActor
final class FreeWalkStage: WalkStage {
    init(statusItem: StatusItemController, fallback: StretchStage, settings: AppSettings)
}
```

## Requirements

1. `prepare()`: if `!settings.freeWalkEnabled` or `!MenuBarScanner.isTrusted`, use the fallback
   for this walk. Otherwise scan, build a `MenuBarLayout` (our item from `statusItem.window`, the
   home sprite x from `statusItem.spriteX(offset: 0)` converted to screen coordinates, notch areas
   as `blocked`), and call `FreeSpace.plan`. A nil plan, or a scan that isn't believable (no app
   menus, zero-size frames, our own item missing), uses the fallback; log the reason.
2. `show(output)`: offset 0 → the buddy at home in the status item, window hidden. Offset inside
   `plan.visible` → the window at home x + offset, and the status item shows nothing (or an
   "out" marker if you add one; keep it subtle). Otherwise the buddy is behind other icons: both
   hidden.
3. `finish()`: hide and release the window, show the buddy at home, and remove any observers.
4. While walking, re-scan on `NSWorkspace.didActivateApplicationNotification` and screen
   parameter changes, and report the new plan's `targets` (or nil) through `onRoomChanged`.
5. The window: borderless, `.nonactivatingPanel`, clear background, no shadow, never key, on all
   Spaces, above the menu bar. Clicks on it call `onClick`, which `AppDelegate` wires to
   `buddy.handle(.clicked)`. It must not take focus from the frontmost app.
6. Turning on "Walk on the Whole Bar" without permission calls `MenuBarScanner.requestTrust()`.

## Steps

1. Build `WalkWindow` and try it alone first: show it at a fixed x for a few seconds behind a
   temporary debug path, and check it sits above the menu bar on this Mac, in full-screen Spaces
   too, and that clicks reach it. Remove the debug path afterwards.
2. Write `FreeWalkStage` against the requirements.
3. Wire settings, menu and `AppDelegate`.
4. Record in `docs/menubar.md#free-walk` the window level and collection behaviour
   that worked, and anything surprising.

## Rules

- Still one clock. The window moves only when the engine's output changes.
- No scanning on a timer. Hide the window when not walking; never leave it on screen.
- Everything degrades to a stretch walk, never to a broken walk.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] With free walk off, behaviour is exactly T09's
- [ ] `docs/menubar.md` records the chosen window settings

## Manual check

1. Run `./scripts/run.sh`.
2. Ask: "Turn on Walking → Walk on the Whole Bar (allow Accessibility if asked), then Walk now.
   Does the buddy disappear from its icon, show up in the empty part of the menu bar, walk, rest and
   come back, without covering any menu or icon? Click it while it's out: does it go home? Turn
   free walk off: are walks back to the widening icon?"

## Out of scope

- Following the website's sky or music.

## Notes

- If T10 found status items only through one of `extras` or `agentItems`, use that one.
- Clicking an `NSPanel` with `.nonactivatingPanel` doesn't activate the app; that's the point.
