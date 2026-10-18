# T29 · Bigger buddy, solid outline

Phase 2 · Target: AashSprites + Aash · Risk: low · Detail: full

## Goal

On Retina screens the buddy is a third bigger (sprite pixel 2 pt, not 1.5 pt), and the outline on
a dark menu bar is solid instead of a soft, half-see-through grey.

## Read first

- `docs/sprites.md#sheet-layout`, `#outline`, `#size-on-screen`
- `Sources/AashSprites/SpriteStyle.swift`, `Sources/Aash/SpriteLayerView.swift`
- `Tests/AashSpritesTests/SpriteSheetTests.swift`

## Files

- edit `Sources/AashSprites/SpriteStyle.swift`
- edit `Sources/Aash/SpriteLayerView.swift`: `spriteWidth` for Retina
- edit `Sources/Aash/WalkWindow.swift`: the width constant (it must match `spriteWidth`)
- edit `Tests/AashSpritesTests/SpriteSheetTests.swift`: new sizes and outline values
- edit `docs/sprites.md`: the numbers

## Requirements

1. `SpriteStyle.light` and `.dark` use `pixelSize: 4` (device pixels). `.lowResolution` stays at 2.
2. `SpriteStyle.outlineColor` becomes `#ede6f2` at alpha 255. Update its doc comment.
3. On Retina the shown cell is `10 × 4 / 2` = 20 pt wide and `13 × 4 / 2` = 26 pt tall, so
   `SpriteLayerView.spriteWidth` is 20 on Retina (16 elsewhere, unchanged). `WalkWindow` uses the
   same 20 (better: read it from one place; if `WalkWindow` can take it from `SpriteLayerView`,
   do that and drop the duplicate constant).
4. The cell is 26 pt tall and the bar 24 pt, so the 1-pixel outline margin at the top and bottom
   is clipped by about 1 pt. That is accepted. Don't shrink the art to avoid it. If the art
   itself (the 8 × 11 grid, 16 × 22 pt) is clipped, report `RESULT: blocked` with a screenshot or
   a description.
5. Everything else (sheet layout, `contentsRect`, the cache keyed by style, mirroring) stays.
   `StatusItemController.spriteX` already uses `spriteWidth`, so the home position follows.

## Steps

1. Change the style values and the outline colour.
2. Change `spriteWidth` and `WalkWindow`'s width.
3. Update the tests. The old ones hard-code pixel positions for `pixelSize` 3 (for example sheet
   210 × 39, `x: 42, y: 12`, `x: 9, y: 0`). Recompute the positions for `pixelSize` 4: sheet
   280 × 52, and sprite pixel `(c, r)` of frame `i` sits at
   `x = i × 40 + (c + 1) × 4 + 2`, `y = (r + 1) × 4 + 2` (a point inside the pixel). Keep what
   each test checks. `darkOutlineAboveHair` now expects exactly `#ede6f2` with alpha 255.
4. Update the numbers in `docs/sprites.md`: Retina `pixelSize` 4, sprite pixel 2 pt, cell
   20 × 26 pt, outline alpha 255, the sheet size, and the sentence about clipping.

## Rules

- Whole device pixels only.
- Don't change the sprite art (`SpriteArt.swift`).

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`

## Manual check

1. Run `./scripts/run.sh`.
2. Ask: "Is the buddy a bit bigger, still sharp, and fully inside the menu bar (nothing important
   cut off)? On a dark menu bar is the outline now solid and clean instead of a grey halo? Walk
   now: does the walking buddy look the same size as the one at home?"

## Out of scope

- A different art style or outline shape, non-Retina sizes, the app icon.
