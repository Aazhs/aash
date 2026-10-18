# Sprites

The buddy is the character from aarshj.me: an 8×11 pixel grid with a 6-colour palette, plus one
extra colour for closed eyes. All frames are drawn once into one sprite-sheet image; showing a
frame just moves the layer's `contentsRect`.

## Source

The website draws the character from string grids in
`~/Codes/aarshj_website/aarshj.me/src/PixelScene.jsx` (lines 32–73: `SPRITE_IDLE`, `SPRITE_WALK`,
`SPRITE_ARMS`, `SPRITE_COLORS`). `idle`, `walk` and `armsUp` below are copied from it exactly.
`blink`, `wave`, `waveHigh` and `sleep` were drawn for the app, in the same style.

If the website's character changes, update the grids here first, then in
`Sources/AashSprites/SpriteArt.swift`.

## Palette

| Key | Part | Colour |
|---|---|---|
| `.` | transparent | — |
| `1` | hair | `#2a1b2e` |
| `2` | skin | `#f2c9a8` |
| `3` | hoodie | `#8fd3c9` |
| `4` | trousers | `#3f2740` |
| `5` | shoes | `#1b1120` |
| `6` | eyes (open) | `#2a1b2e` |
| `7` | eyes (closed) | `#c08f74` (new; darker skin) |

All colours are fully opaque.

## Frames

Every frame is 8 columns × 11 rows. Row 0 is the top. The character faces right; facing left is a
mirror done by the layer, not separate art.

```
idle        blink       walk        armsUp      wave        waveHigh    sleep
..1111..    ..1111..    ..1111..    2.1111.2    ..1111..    ..1111.2    ........
.111111.    .111111.    .111111.    21111112    .111111.    .1111112    ..1111..
.122221.    .122221.    .122221.    31222213    .122221.    .1222213    .111111.
.126262.    .127272.    .126262.    3126262.    .126262.    .126262.    .122221.
..2222..    ..2222..    ..2222..    .32222..    ..2222.2    ..2222..    .127272.
.333333.    .333333.    .333333.    .333333.    .3333333    .333333.    ..2222..
33333333    33333333    33333333    ..3333..    3333333.    3333333.    .333333.
2.3333.2    2.3333.2    2.3333.2    ..3333..    2.3333..    2.3333..    33333333
..4444..    ..4444..    ..4444..    ..4444..    ..4444..    ..4444..    2.3333.2
..4..4..    ..4..4..    .4....4.    ..4..4..    ..4..4..    ..4..4..    .444444.
..5..5..    ..5..5..    .5....5.    ..5..5..    ..5..5..    ..5..5..    .55..55.
```

| Frame | Used for |
|---|---|
| `idle` | Standing still; also the second frame of the walk cycle |
| `blink` | 0.15 s every 3–6 s while idle |
| `walk` | Alternates with `idle` while walking (the website's walk cycle) |
| `armsUp` | A short cheer when a chat reply arrives |
| `wave` | Alternates with `waveHigh` when a reminder is due |
| `waveHigh` | See `wave` |
| `sleep` | Night: sitting, eyes closed |

`SpriteFrame.allCases` must list them in exactly this order: `idle, blink, walk, armsUp, wave,
waveHigh, sleep`. The sheet's layout depends on it.

## Sheet layout

- One row of cells, one cell per frame, left to right in `SpriteFrame.allCases` order.
- Each cell is 10 × 13 sprite pixels: the 8 × 11 grid plus a 1-pixel margin on every side, kept
  for the outline. Without an outline the margin is transparent.
- Each sprite pixel is `pixelSize` × `pixelSize` device pixels. Whole numbers only.
- Frame `i` of `n` has `contentsRect = CGRect(x: i/n, y: 0, width: 1/n, height: 1)`.
- Sheet size in device pixels: `(10 × n × pixelSize) × (13 × pixelSize)`. For 7 frames at
  `pixelSize` 4: 280 × 52.

## Outline

The buddy has no outline. The dark-appearance sheet is drawn exactly like the light one and the
1-pixel margin stays transparent. `SpriteStyle.outline` and the renderer's outline pass stay in
the code but no style uses them.

## Size on screen

| Display | `pixelSize` (device px) | Sprite pixel | Shown on screen |
|---|---|---|---|
| Retina (`backingScaleFactor` 2) | 4 | 2 pt | the whole 10 × 13 cell: 20 × 26 pt |
| Non-Retina (scale 1) | 2 | 2 pt | the no-outline sheet, without its margin: 16 × 22 pt |

- The status item is 22 pt wide (`length = 22`); its button is 22 × 22 pt on macOS 27. The sprite is
  centred in it, at whole device pixels.
- On Retina the 26 pt cell is taller than the 24 pt bar, so about 1 pt of the outline margin at the top and bottom is clipped; the 8 × 11 art (16 × 22 pt) is not.
- Without the margin means the frame's `contentsRect` is inset by 1 sprite pixel on every side:
  1/10 of the cell's width and 1/13 of its height.

## Drawing rules

- Build sheets once per (style, appearance) and keep them. The view only changes `contentsRect`,
  position and the mirror transform, inside `CATransaction` with actions disabled
  (`patterns.md#sprite-layer`).
- `magnificationFilter = .nearest`. Positions are rounded to whole device pixels.
- The sheet is drawn into a `CGContext` with an sRGB colour space and premultiplied alpha. Remember
  `CGContext` puts y = 0 at the bottom: grid row `r` goes to y = `(13 - 1 - (r + 1)) × pixelSize`
  inside its cell.
