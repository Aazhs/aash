# T01 · Sprite art

Phase 1 · Target: AashSprites · Risk: low · Detail: full

## Goal

`AashSprites` holds the buddy's seven frames and palette exactly as written in
`docs/sprites.md`, with tests that prove every grid is the right size and uses only palette
colours.

## Read first

- `docs/sprites.md#palette` and `docs/sprites.md#frames`: the data to port, character for character
- `docs/patterns.md#tests`: how tests are written

## Files

- create `Sources/AashSprites/RGBA.swift`
- create `Sources/AashSprites/SpriteFrame.swift`
- create `Sources/AashSprites/SpriteArt.swift`
- delete `Sources/AashSprites/AashSprites.swift` (Phase 0 placeholder)
- create `Tests/AashSpritesTests/SpriteArtTests.swift`
- delete `Tests/AashSpritesTests/AashSpritesTests.swift` (Phase 0 placeholder)

## Interfaces

```swift
// RGBA.swift
/// A colour with 8-bit channels, not premultiplied.
public struct RGBA: Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8
    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255)
    /// Parses "#rrggbb" or "rrggbb" (either case). Returns nil for anything else.
    public init?(hex: String)
}

// SpriteFrame.swift
/// Every frame of the buddy, in sprite-sheet order.
public enum SpriteFrame: String, CaseIterable, Sendable {
    case idle, blink, walk, armsUp, wave, waveHigh, sleep
}

// SpriteArt.swift
/// The buddy's pixel art: the grids and palette from docs/sprites.md.
public enum SpriteArt {
    public static let width = 8
    public static let height = 11
    /// Colour for each grid character. "." is transparent and isn't in the palette.
    public static let palette: [Character: RGBA]
    /// The grid for a frame: `height` strings of `width` characters each, row 0 at the top.
    public static func rows(for frame: SpriteFrame) -> [String]
    /// The colour at column `x`, row `y` (row 0 at the top), or nil when transparent or out of range.
    public static func color(of frame: SpriteFrame, x: Int, y: Int) -> RGBA?
}
```

## Steps

1. Write `RGBA`. `init?(hex:)`: drop one leading `#` if present; the rest must be exactly 6
   characters; parse each pair with `UInt8(_, radix: 16)`; any failure returns nil. Alpha is 255.
2. Write `SpriteFrame` with the cases in exactly this order: `idle, blink, walk, armsUp, wave,
   waveHigh, sleep`.
3. Write `SpriteArt.palette` with the seven entries from `docs/sprites.md#palette`, keys `"1"` to
   `"7"`. Build each value with `RGBA(r:g:b:)` from the hex in the doc; don't parse strings at runtime.
4. Write `rows(for:)` as a `switch` returning the grid strings from `docs/sprites.md#frames`.
   Copy them exactly. Each frame is a column in that block: read down a column to get its 11 rows.
5. Write `color(of:x:y:)`: out of range → nil; the character at `rows(for: frame)[y]`, index `x`;
   `"."` → nil; otherwise `palette[character]`.
6. Delete the two placeholder files with `git rm`. Write the tests below.
7. Run `./scripts/check.sh --target AashSprites` while working (this card runs in parallel with
   T03). Finish with it passing; the orchestrator runs the full check.

## Rules

- Copy the grids exactly. A single wrong character is a visible bug.
- Public declarations get a one-line `///` doc comment (CLAUDE.md, Style).
- No AppKit, no CoreGraphics needed in this card: Foundation only.

## Done when

- [ ] `./scripts/check.sh --target AashSprites` passes, and the orchestrator's full
  `./scripts/check.sh` prints `CHECK PASS`
- [ ] Tests in `Tests/AashSpritesTests/SpriteArtTests.swift`, inside `@Suite struct SpriteArtTests`:
  - `everyFrameIs8By11`: for every `SpriteFrame.allCases`, `rows(for:)` has 11 strings of 8 characters
  - `gridsUseOnlyPaletteCharacters`: every character in every grid is `"."` or a palette key
  - `paletteMatchesDocs`: `palette["1"] == RGBA(hex: "#2a1b2e")`, `"2"` → `#f2c9a8`,
    `"3"` → `#8fd3c9`, `"4"` → `#3f2740`, `"5"` → `#1b1120`, `"6"` → `#2a1b2e`, `"7"` → `#c08f74`
  - `websiteFramesAreExact`: `rows(for: .idle)`, `.walk` and `.armsUp` equal these literals:
    - idle: `["..1111..", ".111111.", ".122221.", ".126262.", "..2222..", ".333333.", "33333333", "2.3333.2", "..4444..", "..4..4..", "..5..5.."]`
    - walk: `["..1111..", ".111111.", ".122221.", ".126262.", "..2222..", ".333333.", "33333333", "2.3333.2", "..4444..", ".4....4.", ".5....5."]`
    - armsUp: `["2.1111.2", "21111112", "31222213", "3126262.", ".32222..", ".333333.", "..3333..", "..3333..", "..4444..", "..4..4..", "..5..5.."]`
  - `frameOrderIsFixed`: `SpriteFrame.allCases.map(\.rawValue) == ["idle", "blink", "walk", "armsUp", "wave", "waveHigh", "sleep"]`
  - `hexParsing`: `RGBA(hex: "#ff0080") == RGBA(r: 255, g: 0, b: 128)`;
    `RGBA(hex: "00FF00") == RGBA(r: 0, g: 255, b: 0)`; `RGBA(hex: "#fff") == nil`;
    `RGBA(hex: "zzzzzz") == nil`; `RGBA(hex: "") == nil`
  - `colorLookup`: `color(of: .idle, x: 2, y: 0) == palette["1"]`;
    `color(of: .idle, x: 0, y: 0) == nil`; `color(of: .idle, x: 8, y: 0) == nil`;
    `color(of: .idle, x: 0, y: -1) == nil`; `color(of: .blink, x: 3, y: 3) == palette["7"]`
  - `blinkOnlyClosesTheEyes`: comparing `.idle` and `.blink` pixel by pixel, they differ at exactly
    two positions, (3, 3) and (5, 3)

## Out of scope

- Drawing images, sprite sheets, CoreGraphics: that's T02.
- Any frame not listed in the doc.

## Notes

- `Character` keys: write them as `"1"` with an explicit type, e.g.
  `public static let palette: [Character: RGBA] = ["1": RGBA(r: 0x2a, g: 0x1b, b: 0x2e), ...]`.
- Index a `String` by converting the row once: `Array(row)[x]`.
