# T25 · App icon

Phase 5 · Target: tools + Resources · Risk: low · Detail: full

## Goal

Aash has an app icon in Finder, the About panel and Login Items: the idle sprite on a rounded
lavender tile. A script makes it from `SpriteArt`, so it always matches the sprite.

## Read first

- `docs/sprites.md#palette` and `#frames`
- `scripts/lib.sh`: `QOS` and the log folder. The new script follows `scripts/build.sh`'s style.

## Files

- create `tools/make-icon/main.swift`
- create `scripts/make-icon.sh`. The card permits this one new file in the protected `scripts/`
  folder. Don't edit the other scripts.
- create `Resources/AppIcon.icns`, made by the script
- edit `Resources/Info.plist`: add `CFBundleIconFile` = `AppIcon`

`scripts/build.sh` already copies `Resources/AppIcon.icns` into the bundle when it exists.

## Interfaces

`tools/make-icon/main.swift` is compiled together with `Sources/AashSprites/*.swift` into one
small binary, so it uses `SpriteArt` and `RGBA` directly. Don't `import AashSprites`: they are in
the same module. Write it exactly like this:

```swift
import CoreGraphics
import Foundation
import ImageIO

// Draws Aash's iconset from the idle sprite. Usage: make-icon <output .iconset folder>
// Built and run by scripts/make-icon.sh together with Sources/AashSprites.

/// The tile behind the buddy: #ede6f2, the outline colour from docs/sprites.md.
let tile = RGBA(r: 0xed, g: 0xe6, b: 0xf2, a: 255)

/// One icon image `n` × `n` pixels: a rounded tile with the idle frame centred on it.
func drawIcon(size n: Int) -> CGImage? {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    func color(_ c: RGBA) -> CGColor {
        CGColor(srgbRed: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255,
                alpha: CGFloat(c.a) / 255)
    }
    // Apple's 1024 grid: an 824 px tile, 100 px in from each edge, corners about 185 px.
    let inset = Int((Double(n) * 100 / 1024).rounded())
    let side = n - 2 * inset
    let radius = CGFloat(side) * 0.225
    ctx.addPath(CGPath(roundedRect: CGRect(x: inset, y: inset, width: side, height: side),
                       cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(color(tile))
    ctx.fillPath()

    // Whole device pixels per sprite pixel keep the art crisp; it fills about 62% of the tile's height.
    let p = max(1, side * 62 / 100 / SpriteArt.height)
    let originX = (n - SpriteArt.width * p) / 2
    let originY = (n - SpriteArt.height * p) / 2
    ctx.setShouldAntialias(false)
    for gy in 0..<SpriteArt.height {
        for gx in 0..<SpriteArt.width {
            guard let c = SpriteArt.color(of: .idle, x: gx, y: gy) else { continue }
            ctx.setFillColor(color(c))
            // Row 0 is the top; CoreGraphics counts from the bottom.
            ctx.fill(CGRect(x: originX + gx * p, y: originY + (SpriteArt.height - 1 - gy) * p,
                            width: p, height: p))
        }
    }
    return ctx.makeImage()
}

/// Writes `image` as a PNG. Returns false on failure.
func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon <output .iconset folder>\n".utf8))
    exit(2)
}
let folder = URL(fileURLWithPath: arguments[1], isDirectory: true)
// iconutil's names: icon_<points>x<points>[@2x].png
let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for entry in entries {
    guard let image = drawIcon(size: entry.pixels),
          writePNG(image, to: folder.appendingPathComponent("\(entry.name).png")) else {
        FileHandle.standardError.write(Data("make-icon: couldn't write \(entry.name).png\n".utf8))
        exit(1)
    }
}
```

This exact code was compiled with `xcrun swiftc -swift-version 6 -O` on this Mac during
planning. It drew the expected icon, and `iconutil` accepted the result (68 KB).

## Steps

1. Create `tools/make-icon/main.swift` with the code above.
2. Create `scripts/make-icon.sh` (bash, `chmod +x`):
   ```bash
   #!/bin/bash
   # Draw the app icon from the idle sprite into Resources/AppIcon.icns.
   #   scripts/make-icon.sh
   # Prints one result line. Full log: build/logs/make-icon.log
   source "$(dirname "$0")/lib.sh"

   LOG=build/logs/make-icon.log
   OUT=build/icon
   rm -rf "$OUT"
   mkdir -p "$OUT/AppIcon.iconset"

   if ! taskpolicy -c "$QOS" xcrun swiftc -swift-version 6 -O tools/make-icon/main.swift \
       Sources/AashSprites/*.swift -o "$OUT/make-icon" >"$LOG" 2>&1; then
     echo "ICON FAIL (compile) · log: $LOG"
     clean <"$LOG" | grep -E "error:" | head -10
     exit 1
   fi
   if ! "$OUT/make-icon" "$OUT/AppIcon.iconset" >>"$LOG" 2>&1 ||
      ! iconutil -c icns "$OUT/AppIcon.iconset" -o Resources/AppIcon.icns >>"$LOG" 2>&1; then
     echo "ICON FAIL · log: $LOG"
     tail -5 "$LOG"
     exit 1
   fi
   echo "ICON OK · Resources/AppIcon.icns · $(stat -f%z Resources/AppIcon.icns) bytes"
   ```
3. Run `./scripts/make-icon.sh`. It prints `ICON OK`.
4. In `Resources/Info.plist`, add `CFBundleIconFile` with the string `AppIcon`, after
   `CFBundleExecutable`.
5. Run `./scripts/check.sh`.

## Rules

- `tools/` isn't a SwiftPM target, and `Package.swift` doesn't change.
- Only the script runs `swiftc`, never you directly (CLAUDE.md, Commands).
- Commit the generated `Resources/AppIcon.icns`. Nothing in `build/` is committed.

## Done when

- [ ] `./scripts/make-icon.sh` prints `ICON OK`
- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `plutil -extract CFBundleIconFile raw Resources/Info.plist` prints `AppIcon`
- [ ] `ls build/Aash.app/Contents/Resources/AppIcon.icns` exists after the check
- [ ] No new tests: `tools/` has none

## Manual check

The orchestrator runs `./scripts/run.sh`, opens `build/icon/AppIcon.iconset/icon_256x256.png`
with the Read tool and looks at it, then asks: "Right-click the buddy → About Aash. Does the About
panel show the pixel buddy on a lavender rounded square?"

If the user wants it in Finder too, run `./scripts/install.sh`. `~/Applications/Aash.app` then
shows the same icon. Finder may cache an old icon for a minute.

## Out of scope

- A dark-mode or tinted icon variant, or an Asset Catalog.
- Changing the menu bar sprite.
- A different background colour, unless the user asks in the manual check.

## Notes

- At 16 px the art is drawn at 1 px per sprite pixel (8 × 11 on a 12 px tile), so it's tiny but
  sharp.
