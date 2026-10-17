# T08 · Stretch walk

Phase 2 · Target: Aash · Risk: medium · Detail: full

## Goal

Every 5–15 minutes, or on "Walk now", the status item widens to the left, the buddy walks out
inside it, rests, walks back, and the item shrinks again. The walk goes through a `WalkStage`, so
T12 can add a second kind of walk without touching `BuddyController` again.

## Read first

- `docs/behaviour.md#the-walk-handshake`
- `docs/menubar.md#stretch-walk`
- `docs/patterns.md#settings` and `#status-item`
- `Sources/Aash/BuddyController.swift`, `StatusItemController.swift`, `AppMenu.swift`, `AppDelegate.swift`

## Files

- create `Sources/Aash/WalkStage.swift`
- create `Sources/Aash/StretchStage.swift`
- create `Sources/Aash/AppSettings.swift`
- edit `Sources/Aash/BuddyController.swift`: take a stage, run the handshake, walking from settings
- edit `Sources/Aash/AppMenu.swift`: add "Walk now" and "Walking"
- edit `Sources/Aash/AppDelegate.swift`: wiring

## Interfaces

```swift
// WalkStage.swift
import AashCore

/// Where a walk happens. BuddyController uses one stage at a time.
@MainActor
protocol WalkStage: AnyObject {
    /// Makes room for a walk; returns where it may end, as offsets from home, or nil for no room.
    func prepare() async -> ClosedRange<Double>?
    /// Draws the buddy while a walk is on.
    func show(_ output: BuddyOutput)
    /// The walk is over: gives the room back. Safe to call more than once.
    func finish()
}

// StretchStage.swift
/// Walks inside the status item, widened to the left (docs/menubar.md#stretch-walk).
@MainActor
final class StretchStage: WalkStage {
    /// `distance` is read at the start of each walk, in points.
    init(statusItem: StatusItemController, distance: @escaping @MainActor () -> Double)
}

// AppSettings.swift: patterns.md#settings, with these two keys
@MainActor
final class AppSettings {
    init(defaults: UserDefaults = .standard)
    /// Whether the buddy goes for walks. Default true.
    var walkingEnabled: Bool { get set }
    /// How far a stretch walk may go, in points. Default 120; reads and writes are clamped to 24...240.
    var walkDistance: Double { get set }
}

// BuddyController: replace the T04 init and start
init(statusItem: StatusItemController, stage: WalkStage, clock: AnimationClock = AnimationClock(), now: Date = Date())
/// Connects the clock and clicks, sends the walking setting, and shows the first output.
func start(walkingEnabled: Bool)

// AppMenu: replace the T06 init
init(settings: AppSettings, onWalkNow: @escaping () -> Void, onWalkingChanged: @escaping (Bool) -> Void)
```

## Steps

1. `AppSettings`: keys `walkingEnabled` and `walkDistance`, defaults as above. Add `walkDistance`
   to the table in `docs/architecture.md#settings-keys` (it's already listed; check it says T08).
2. `StretchStage`:
   - `prepare()`: `let d = distance()`; set `statusItem.length = StatusItemController.homeLength + d`;
     return `-d ... 0`.
   - `show(_:)`: `statusItem.spriteView.show(SpriteFrame(output.pose), facingLeft: output.facingLeft,
     x: statusItem.spriteX(offset: output.offset))`.
   - `finish()`: `statusItem.length = StatusItemController.homeLength`.
3. `BuddyController`:
   1. Store the stage. Add `private var walking = false` and `private var prepareTask: Task<Void, Never>?`.
   2. `start(walkingEnabled:)`: as T04's `start()`, but send `.walkingEnabled(walkingEnabled)`
      instead of `false`. Remove the T04 comment.
   3. Replace the apply step with this order:
      1. If `output.needsWalkArea` and not `walking`: set `walking = true`; start
         `prepareTask = Task { @MainActor [weak self] in ... }` that awaits `stage.prepare()`, then,
         if still `walking`, calls `handle(.walkArea(area))`.
      2. If `walking`, `!output.needsWalkArea` and `output.offset == 0`: set `walking = false`,
         cancel `prepareTask`, call `stage.finish()`.
      3. If `walking`: `stage.show(output)`. Otherwise show at home through the status item as in T04.
      4. `clock.apply(output.schedule)`.
4. `AppMenu`: add before the existing items, in order:
   1. "Walk now" → `onWalkNow()`; enabled only while `settings.walkingEnabled` (use
      `validateMenuItem` or set `isEnabled` in `menuNeedsUpdate`, with `menu.autoenablesItems = false`).
   2. "Walking" → toggles `settings.walkingEnabled`, then `onWalkingChanged(newValue)`; checkmark
      from the setting in `menuNeedsUpdate`.
   3. a separator
5. `AppDelegate`: create `AppSettings`; create
   `StretchStage(statusItem: item, distance: { [weak settings] in settings?.walkDistance ?? 120 })`;
   pass it to `BuddyController`; call `start(walkingEnabled: settings.walkingEnabled)`; create
   `AppMenu` with closures that call `buddy.handle(.walkNow)` and `buddy.handle(.walkingEnabled(on))`
   (capture `[weak buddy]`). Keep strong references to `settings`, the stage and the menu.

## Rules

- `BuddyController` must not know which stage it has: only the `WalkStage` protocol.
- One clock: the walk's 8 fps comes from the engine's `.every` schedule, not a new timer.
- Every layer change still goes through `SpriteLayerView.show` (actions disabled).

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `grep -rn "StretchStage" Sources/Aash/BuddyController.swift` finds nothing

## Manual check

1. Run `./scripts/run.sh`.
2. Ask: "Right-click → Walk now. Does the icon widen to the left, the buddy walk left, rest a few
   seconds and walk back, and the icon return to its normal size? Icons to the left should slide
   over and back. Then right-click → Walking to turn walks off: is Walk now greyed out?"

## Out of scope

- Screen changes, a crowded bar, the bar hiding mid-walk: T09.
- Free walk over the bar: T10–T12.

## Notes

- The engine snaps home on `clicked`, `chatOpened` and `paused(true)`; with the order in step 3.3,
  that ends the walk and shrinks the item automatically.
- `prepare()` is `async` for T12, which needs to scan the bar; the stretch stage returns at once.
