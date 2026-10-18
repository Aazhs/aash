# T28 · Walk out of the icon

Phase 2 · Target: Aash · Risk: low · Detail: full

## Goal

When no other status item is to the left of ours, a free walk starts and ends at the buddy's own
icon: it doesn't vanish for the first and last ~30 pt. When other icons are to the left, nothing
changes (the buddy is hidden behind them).

## Read first

- `Sources/Aash/FreeWalkStage.swift`, `measure()`
- `Sources/AashCore/FreeSpace.swift`
- `docs/menubar.md#free-walk`

## Files

- edit `Sources/Aash/FreeWalkStage.swift`
- edit `Tests/AashCoreTests/FreeSpaceTests.swift`: one new test
- edit `docs/menubar.md`: one short paragraph under "Rules for free walk"

## Why

`measure()` sets `statusItemsMinX` to the left edge of the leftmost status item, our own included.
`FreeSpace.plan` keeps the sprite `margin + spriteWidth` clear of it, so the right end of the
visible range lies about 26 pt to the left of home. Between that and home the buddy is hidden
(T12, rule 2). That is right for other apps' icons, but our own icon is empty while the buddy is
out (its sprite is hidden), so the buddy may walk over it.

## Requirements

1. In `measure()`, split `extras` into our own item (the one whose frame contains the centre of
   `itemWindow.frame`, as the existing "own item missing" guard finds it) and `others`.
2. Let `leftOthers` be the items in `others` whose `frame.midX` is less than our item's `midX`.
   - If `leftOthers` is not empty: `itemsMinX` is the smallest `frame.minX` among them. This is
     today's behaviour when something is to our left.
   - If it is empty: `itemsMinX = home + spriteWidth + margin`, so that `FreeSpace.plan` gives a
     visible range whose upper bound is 0. Use one local `let margin = 8.0` for both this and the
     `margin:` argument you pass to `FreeSpace.plan`.
3. Keep the "menus reach the status items" guard, comparing `menusMaxX` with the new `itemsMinX`.
4. Items to the right of ours are ignored, as before in effect (they can't be reached).
5. `FreeSpace.swift` does not change.

## Steps

1. Compute `home` before `itemsMinX` (it needs the home x), then apply requirements 1 to 3.
2. Add the test, in `FreeSpaceTests`, inside the existing suite, with the standard layout:
   `homeIsTheRightEnd`: status items start at `1021.5 + 8 + 15` = 1044.5, home sprite at 1021.5,
   sprite width 15, margin 8 → `visible.upperBound == 0` (tolerance 0.0001).
3. Add a short paragraph to `docs/menubar.md`: if our icon is the leftmost status item the buddy
   may cover it while out; otherwise it stays hidden until it is clear of the icons to its left.

## Rules

- No new timers, no new files.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`

## Manual check

1. Run `./scripts/run.sh`.
2. Ask: "Right-click → Walk now. Does the buddy now walk straight out of its icon and back into
   it, without vanishing for a moment at the start and the end?"

## Out of scope

- Changing `FreeSpace`, the walk window or the hand-off logic.
- Hiding icons, notch handling.
