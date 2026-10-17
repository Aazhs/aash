# T11 · Free-space maths

Phase 2 · Target: AashCore · Risk: low · Detail: full

## Goal

A pure function turns the menu bar's geometry into a free-walk plan: where a walk may end, and
where along the way the buddy is visible (elsewhere it's hidden behind other icons). Tests cover
the layouts it must handle.

## Read first

- `docs/menubar.md#free-walk` and `#accessibility-findings` (T10's results)
- `docs/behaviour.md#the-walk-handshake` and the `walkArea` row in `#events`
- `docs/patterns.md#tests`

## Files

- create `Sources/AashCore/FreeSpace.swift`
- create `Tests/AashCoreTests/FreeSpaceTests.swift`

## Interfaces

```swift
// FreeSpace.swift
/// The menu bar along x, in screen points (AppKit coordinates).
public struct MenuBarLayout: Equatable, Sendable {
    /// The screen's left and right edges.
    public var screen: ClosedRange<Double>
    /// Right edge of the frontmost app's last menu; nil when unknown.
    public var appMenusMaxX: Double?
    /// Left edge of the leftmost status item, ours included.
    public var statusItemsMinX: Double
    /// Where the sprite's left edge is when the buddy is home.
    public var homeSpriteX: Double
    /// Ranges to keep clear, such as the camera notch.
    public var blocked: [ClosedRange<Double>]
    public init(screen: ClosedRange<Double>, appMenusMaxX: Double?, statusItemsMinX: Double,
                homeSpriteX: Double, blocked: [ClosedRange<Double>] = [])
}

/// A free walk, as offsets from home (negative = left).
public struct FreeWalkPlan: Equatable, Sendable {
    /// Where a walk may end. Pass it to the engine as `walkArea`.
    public var targets: ClosedRange<Double>
    /// Offsets at which the buddy is drawn. Between `visible.upperBound` and 0 it's behind icons.
    public var visible: ClosedRange<Double>
}

/// Free-walk geometry.
public enum FreeSpace {
    /// The plan for a walk, or nil when the free stretch is shorter than `minWalkDistance`.
    public static func plan(for layout: MenuBarLayout, spriteWidth: Double,
                            margin: Double = 8, minWalkDistance: Double = 24) -> FreeWalkPlan?
}
```

## Steps

1. `left` = `(layout.appMenusMaxX ?? layout.screen.lowerBound + (layout.screen.upperBound − layout.screen.lowerBound) / 2) + margin`.
   Without menu information, keep to the right half of the screen.
2. `right` = `layout.statusItemsMinX − margin − spriteWidth`: the furthest right the sprite's left
   edge may be while staying clear of every status item.
3. For each blocked range `b`, sorted by `lowerBound`: if `b` overlaps
   `(left − margin) ... (right + spriteWidth + margin)`, set `left = max(left, b.upperBound + margin)`.
   This keeps the stretch nearest home, to the right of the notch.
4. Clamp: `left = max(left, layout.screen.lowerBound + margin)`.
5. If `right − left < minWalkDistance`, return nil.
6. `visible = (left − homeSpriteX) ... (right − homeSpriteX)`; `targets = visible`. Return the plan.

## Rules

- Foundation only; no AppKit types. Points are `Double`.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Tests in `FreeSpaceTests.swift`, inside `@Suite struct FreeSpaceTests`. Unless stated:
  screen `0...1440`, app menus end at 420, status items start at 900, home sprite at 1021.5,
  sprite width 15, margin 8:
  - `typicalBar`: plan is non-nil; `visible == (428 − 1021.5) ... (877 − 1021.5)`, that is
    `-593.5 ... -144.5`; `targets == visible`
  - `unknownMenusUseTheRightHalf`: `appMenusMaxX: nil` → `visible.lowerBound == 728 − 1021.5`
  - `crowdedBarHasNoPlan`: status items start at 450 → nil
  - `notchSplitsTheBar`: blocked `[700...880]`, status items start at 1000 → `visible.lowerBound
    == 888 − 1021.5` and `visible.upperBound == 977 − 1021.5`
  - `notchOutOfTheWay`: blocked `[100...200]` → same plan as `typicalBar`
  - `ourItemIsLeftmost`: status items start at 1010 (ours), home sprite at 1021.5 →
    `visible.upperBound == 987 − 1021.5`, that is −34.5
  - `tinyGapIsNil`: app menus end at 860, status items start at 900 → nil

## Out of scope

- Reading geometry (T10) or walking (T12).

## Notes

- Compare doubles with a tolerance of 0.0001.
