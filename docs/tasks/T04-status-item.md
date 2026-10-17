# T04 · Status item

Phase 1 · Target: Aash · Risk: medium · Detail: full

## Goal

The buddy stands in the menu bar and blinks. `AnimationClock`, `SpriteLayerView`,
`StatusItemController` and `BuddyController` exist and are wired up the way every later card
expects. This card sets the energy behaviour of the whole app, which is why it gets an Opus review.

## Read first

- `docs/architecture.md#data-flow` and `#threading`
- `docs/patterns.md#the-clock`, `#sprite-layer`, `#status-item`, `#logging`
- `docs/sprites.md#size-on-screen`, `#outline` (choosing the sheet), `#drawing-rules`
- `docs/performance.md#rules-that-keep-it-there`
- `Sources/AashSprites/SpriteSheet.swift`, `SpriteRenderer.swift`, `SpriteStyle.swift` (T02)
- `Sources/AashCore/BehaviourEngine.swift`, `BuddyTypes.swift` (T03): the public API only

## Files

- create `Sources/Aash/AnimationClock.swift`
- create `Sources/Aash/SpriteFrame+Pose.swift`
- create `Sources/Aash/SpriteLayerView.swift`
- create `Sources/Aash/StatusItemController.swift`
- create `Sources/Aash/BuddyController.swift`
- edit `Sources/Aash/AppDelegate.swift`: replace the placeholder with the wiring below

## Interfaces

```swift
// AnimationClock.swift: exactly the code in docs/patterns.md#the-clock.

// SpriteFrame+Pose.swift
import AashCore
import AashSprites
extension SpriteFrame {
    /// The sheet frame that shows an engine pose.
    init(_ pose: Pose)   // an exhaustive switch, no default case
}

// SpriteLayerView.swift
@MainActor
final class SpriteLayerView: NSView {
    /// Shows `frame` with its left edge `x` points from this view's left edge, centred vertically.
    func show(_ frame: SpriteFrame, facingLeft: Bool, x: CGFloat)
    /// Width of the drawn sprite in points: 15 on Retina, 16 on a non-Retina screen.
    var spriteWidth: CGFloat { get }
}

// StatusItemController.swift
@MainActor
final class StatusItemController: NSObject {
    /// The item's width while the buddy is home, in points.
    static let homeLength: CGFloat = 22
    let spriteView: SpriteLayerView
    /// Called on a left click.
    var onLeftClick: (() -> Void)?
    /// Shown on a right click.
    var menu: NSMenu?
    override init()
    /// The item's width in points. Setting it widens or narrows the item to the left.
    var length: CGFloat { get set }
    /// The window that hosts the item, for occlusion and its position on screen.
    var window: NSWindow? { get }
    /// The sprite's left edge in button coordinates, for an offset from home (docs/menubar.md#stretch-walk).
    func spriteX(offset: Double) -> CGFloat
}

// BuddyController.swift
import AashCore
@MainActor
final class BuddyController {
    /// The engine's latest output.
    private(set) var output: BuddyOutput
    init(statusItem: StatusItemController, clock: AnimationClock = AnimationClock(), now: Date = Date())
    /// Connects the clock and clicks, then shows the first output.
    func start()
    /// Feeds one event to the engine and applies the result.
    func handle(_ event: BuddyEvent)
}
```

## Steps

1. `AnimationClock`: copy `docs/patterns.md#the-clock` exactly.
2. `SpriteFrame(_ pose:)`: one `case` per pose, mapping to the frame with the same name.
3. `SpriteLayerView`:
   1. Start from `docs/patterns.md#sprite-layer`, including `hitTest` returning nil.
   2. Keep a cache `[SpriteStyle: SpriteSheet]` and the last shown `(frame, facingLeft, x)`.
   3. `scale` = `window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2`.
      `isDark` = `effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua`.
      Style: scale ≥ 2 → `isDark ? .dark : .light`; otherwise `.lowResolution`.
   4. `show`: get the sheet for the style (make it with `SpriteRenderer.makeSheet` the first time
      and cache it; if that returns nil, log an error and return). Set `contents` only when the
      sheet changed. `contentsRect`: `contentsRect(for:)` when scale ≥ 2, otherwise
      `contentsRectWithoutMargin(for:)`.
   5. Layer size: scale ≥ 2 → `cellPixelWidth / scale` × `cellPixelHeight / scale` (15 × 19.5 pt);
      otherwise 16 × 22 pt. y = `(bounds.height − height) / 2`. Round x and y to device pixels:
      `(v * scale).rounded() / scale`.
   6. Set `bounds` and `position` (not `frame`), then the mirror transform, all in one
      `CATransaction` with actions disabled.
   7. Re-show the last frame from `viewDidChangeEffectiveAppearance`, `viewDidChangeBackingProperties`
      and `layout()`, so appearance, screen and width changes redraw correctly.
   8. `spriteWidth`: 15 when scale ≥ 2, else 16.
4. `StatusItemController`:
   1. `NSStatusBar.system.statusItem(withLength: Self.homeLength)`.
   2. Button: `image = nil`, `title = ""`, `toolTip = "Aash \(AashCore.version)"`,
      `setAccessibilityTitle("Aash")`. Add `spriteView` with `frame = button.bounds` and
      `autoresizingMask = [.width, .height]`.
   3. Clicks exactly as `docs/patterns.md#status-item`: left → `onLeftClick`, right → `menu`.
   4. `spriteX(offset:)` = `(length − homeLength) + (homeLength − spriteView.spriteWidth) / 2 + offset`.
      Use `length`, not the button's bounds: bounds can lag one layout pass behind a width change.
   5. `window` = `item.button?.window`.
5. `BuddyController`:
   1. `engine = BehaviourEngine(seed: UInt64.random(in: .min ... .max), now: now)`; `output = engine.output`.
   2. `start()`: `clock.onTick = { [weak self] in self?.handle(.tick) }`,
      `statusItem.onLeftClick = { [weak self] in self?.handle(.clicked) }`, then
      `handle(.walkingEnabled(false))`. Walking stays off until T08 adds a walk stage; leave a
      `// T08 turns walking on` comment.
   3. `handle(_:)`: `output = engine.handle(event, now: Date())`, then apply it:
      `statusItem.spriteView.show(SpriteFrame(output.pose), facingLeft: output.facingLeft,
      x: statusItem.spriteX(offset: output.offset))` and `clock.apply(output.schedule)`.
   4. Log `engine.activity` at `.debug` (category `Behaviour`) only when it changes.
6. `AppDelegate`: keep strong references to a `StatusItemController` and a `BuddyController`. In
   `applicationDidFinishLaunching`: create the status item; give it a menu with one item,
   "Quit Aash" (⌘Q, `NSApplication.terminate(_:)`), which T06 replaces; create the buddy
   controller and call `start()`. Remove the placeholder title.

## Rules

- Everything here is `@MainActor`. No `DispatchQueue`, no second timer (CLAUDE.md, rules 5 and 6).
- Layer changes only inside `CATransaction` with actions disabled (`patterns.md#gotchas`).
- Don't override `draw(_:)`. Don't set `button.image`.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] No tests to add: the app target has none. The engine's behaviour is covered by T03.
- [ ] `grep -rn "Timer(" Sources/Aash` finds only `AnimationClock.swift`

## Manual check

1. Run `./scripts/run.sh`.
2. Run `./scripts/measure.sh 30 idle` and include the line in your question.
3. Ask: "Is the buddy standing in your menu bar, blinking every few seconds, and does right-click
   show Quit Aash? If your menu bar is dark, it should have a soft light outline." The measure
   line should say `pass`.

## Out of scope

- Pausing, night handling in the app, the full menu: T05 and T06.
- Walking: T08. Chat: T17.

## Notes

- A `.once(at:)` date already in the past fires immediately. That's fine and expected.
- `handle` is called from inside the clock's tick; `clock.apply` replacing the firing timer is safe.
- If the sprite looks blurry, a position isn't rounded to device pixels, or `magnificationFilter`
  isn't `.nearest`.
