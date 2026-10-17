# T02 · Sprite sheet

Phase 1 · Target: AashSprites · Risk: low · Detail: full

## Goal

`SpriteRenderer.makeSheet(style:)` draws all seven frames into one `CGImage`, with or without the
dark-bar outline, and `SpriteSheet` gives each frame's `contentsRect`. Tests read pixels back to
prove the layout, colours and outline.

## Read first

- `docs/sprites.md#sheet-layout`, `#outline`, `#size-on-screen`, `#drawing-rules`
- `docs/patterns.md#tests`
- `Sources/AashSprites/SpriteArt.swift` (from T01): use `SpriteArt.color(of:x:y:)`

## Files

- create `Sources/AashSprites/SpriteStyle.swift`
- create `Sources/AashSprites/SpriteSheet.swift`
- create `Sources/AashSprites/SpriteRenderer.swift`
- create `Tests/AashSpritesTests/SpriteSheetTests.swift`
- create `Tests/AashSpritesTests/PixelReader.swift` (test helper, code below)

## Interfaces

```swift
// SpriteStyle.swift
/// How a sprite sheet is drawn.
public struct SpriteStyle: Hashable, Sendable {
    /// Device pixels per sprite pixel; a whole number, at least 1.
    public var pixelSize: Int
    /// The outline colour for dark menu bars, or nil for no outline.
    public var outline: RGBA?
    public init(pixelSize: Int, outline: RGBA? = nil)
    /// The outline colour from docs/sprites.md: #ede6f2 at alpha 140.
    public static let outlineColor = RGBA(r: 0xed, g: 0xe6, b: 0xf2, a: 140)
    /// Retina, light menu bar.
    public static let light = SpriteStyle(pixelSize: 3)
    /// Retina, dark menu bar.
    public static let dark = SpriteStyle(pixelSize: 3, outline: outlineColor)
    /// Non-Retina screens (always without outline).
    public static let lowResolution = SpriteStyle(pixelSize: 2)
}

// SpriteSheet.swift
import CoreGraphics

/// Every frame in one image: one cell per frame, left to right in `SpriteFrame.allCases` order.
public struct SpriteSheet {
    /// Cell size in sprite pixels: the 8 × 11 grid plus a 1-pixel margin on every side.
    public static let cellWidth = SpriteArt.width + 2
    public static let cellHeight = SpriteArt.height + 2
    public let image: CGImage
    public let style: SpriteStyle
    public init(image: CGImage, style: SpriteStyle)
    /// One cell's width in device pixels.
    public var cellPixelWidth: Int { get }
    /// One cell's height in device pixels.
    public var cellPixelHeight: Int { get }
    /// The frame's whole cell in unit coordinates, for `CALayer.contentsRect`.
    public func contentsRect(for frame: SpriteFrame) -> CGRect
    /// The frame's cell without its 1-pixel margin, for non-Retina screens.
    public func contentsRectWithoutMargin(for frame: SpriteFrame) -> CGRect
}

// SpriteRenderer.swift
import CoreGraphics

/// Draws sprite sheets from `SpriteArt`.
public enum SpriteRenderer {
    /// Draws every frame into a new sheet. Returns nil only if CoreGraphics can't create a context.
    public static func makeSheet(style: SpriteStyle) -> SpriteSheet?
}
```

## Steps

1. `SpriteStyle`: as above. In `init`, clamp `pixelSize` to at least 1.
2. `SpriteSheet`: `cellPixelWidth = cellWidth × style.pixelSize`, same for height. With
   `n = SpriteFrame.allCases.count` and `i` the frame's index in `allCases`:
   - `contentsRect(for:)` = `CGRect(x: Double(i) / Double(n), y: 0, width: 1 / Double(n), height: 1)`
   - `contentsRectWithoutMargin(for:)` = `CGRect(x: (Double(i) + 1 / 10) / Double(n), y: 1 / 13,
     width: (8 / 10) / Double(n), height: 11 / 13)`, using `cellWidth` and `cellHeight` rather than
     the literals 10 and 13.
3. `SpriteRenderer.makeSheet(style:)`:
   1. `p = style.pixelSize`. Image size: width `cellWidth × n × p`, height `cellHeight × p`.
   2. `CGContext(data: nil, width:, height:, bitsPerComponent: 8, bytesPerRow: 0, space:
      CGColorSpace(name: CGColorSpace.sRGB), bitmapInfo:
      CGImageAlphaInfo.premultipliedLast.rawValue)`. Nil → return nil.
   3. For each frame at index `i`, its cell starts at sprite x `i × cellWidth`.
   4. If `style.outline` is set: for every cell position `(cx, cy)` with `cx` in `0..<cellWidth`
      and `cy` in `0..<cellHeight`, the grid position is `(cx − 1, cy − 1)`. If that grid
      position is transparent (`color(of:)` returns nil, out of range included) and any of its 8
      neighbours is opaque, fill that cell position with the outline colour.
   5. For every opaque grid pixel `(gx, gy)`, fill cell position `(gx + 1, gy + 1)` with its colour.
   6. Filling cell position `(cx, cy)` (cy counted from the top) of cell `i` means:
      `ctx.setFillColor(CGColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a/255))`, then
      `ctx.fill(CGRect(x: (i × cellWidth + cx) × p, y: (cellHeight − 1 − cy) × p, width: p, height: p))`.
      CoreGraphics puts y = 0 at the bottom, hence the flip.
   7. `ctx.makeImage()` → `SpriteSheet(image:style:)`.
4. Add `PixelReader.swift` to the tests exactly as below, then write the tests.

```swift
// Tests/AashSpritesTests/PixelReader.swift
import CoreGraphics

/// Reads pixels from a CGImage in a known format: premultiplied RGBA, rows from the top.
struct PixelReader {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init?(_ image: CGImage) {
        width = image.width
        height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }
        bytes = buffer
    }

    /// Premultiplied RGBA at column x, row y (row 0 at the top).
    func pixel(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let i = (y * width + x) * 4
        return (bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3])
    }
}
```

## Rules

- Pure CoreGraphics. No AppKit, no `NSImage`.
- Build the sheet once per call; no caching inside the library (the app caches).

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Tests in `SpriteSheetTests.swift`, inside `@Suite struct SpriteSheetTests`. "Device pixel
  (x, y)" means `PixelReader.pixel(x:y:)`, y from the top:
  - `lightSheetSize`: `.light` sheet image is 210 × 39
  - `onePixelSheetSize`: `SpriteStyle(pixelSize: 1)` sheet is 70 × 13
  - `idleHairPixel`: `.light` sheet, device pixel (9, 3) equals hair `#2a1b2e` with alpha 255
    (idle grid (2, 0) → cell (3, 1) → device x 9…11, y 3…5)
  - `cornerIsTransparent`: `.light` sheet, device pixel (0, 0) has alpha 0
  - `lightMarginIsTransparent`: `.light` sheet, every device pixel in row 0 and row 38 has alpha 0
  - `darkOutlineAboveHair`: `.dark` sheet, device pixel (9, 0) has alpha 140 and RGB within ±2 of
    (130, 126, 133), the premultiplied outline colour (cell (3, 0) is just above idle's top hair pixel)
  - `outlineDoesNotCoverArt`: `.dark` sheet, device pixel (9, 3) is still hair with alpha 255
  - `secondFrameIsBlink`: `.light` sheet, device pixel (42, 12) equals closed-eye `#c08f74`
    (blink grid (3, 3) → cell (4, 4) of frame 1 → device x 30 + 12, y 12)
  - `contentsRects`: `contentsRect(for: .walk)` equals `CGRect(x: 2/7, y: 0, width: 1/7, height: 1)`
    and `contentsRectWithoutMargin(for: .idle)` equals
    `CGRect(x: 1/70, y: 1/13, width: 8/70, height: 11/13)`, each within 0.0001
  - `pixelSizeClamped`: `SpriteStyle(pixelSize: 0).pixelSize == 1`

## Out of scope

- Showing the sheet in a layer, appearance detection, picking the style: that's T04.
- Mirroring: the layer does it.

## Notes

- Compare `CGRect`s field by field with a tolerance (`abs(a.minX - b.minX) < 0.0001`, and so on);
  floating-point fractions won't be exactly equal.
- If a pixel test fails, print the four channels in the `#expect` message to see what you got.
