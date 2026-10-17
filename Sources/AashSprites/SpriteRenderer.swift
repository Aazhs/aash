import CoreGraphics

/// Draws sprite sheets from `SpriteArt`.
public enum SpriteRenderer {
    /// Draws every frame into a new sheet. Returns nil only if CoreGraphics can't create a context.
    public static func makeSheet(style: SpriteStyle) -> SpriteSheet? {
        let p = style.pixelSize
        let cellW = SpriteSheet.cellWidth
        let cellH = SpriteSheet.cellHeight
        let frames = SpriteFrame.allCases
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: cellW * frames.count * p, height: cellH * p,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        func fill(_ color: RGBA, cell i: Int, cx: Int, cy: Int) {
            ctx.setFillColor(CGColor(srgbRed: CGFloat(color.r) / 255, green: CGFloat(color.g) / 255,
                                     blue: CGFloat(color.b) / 255, alpha: CGFloat(color.a) / 255))
            ctx.fill(CGRect(x: (i * cellW + cx) * p, y: (cellH - 1 - cy) * p, width: p, height: p))
        }

        for (i, frame) in frames.enumerated() {
            if let outline = style.outline {
                for cy in 0..<cellH {
                    for cx in 0..<cellW {
                        let gx = cx - 1, gy = cy - 1
                        guard SpriteArt.color(of: frame, x: gx, y: gy) == nil else { continue }
                        var touches = false
                        for dy in -1...1 {
                            for dx in -1...1 where (dx != 0 || dy != 0) {
                                if SpriteArt.color(of: frame, x: gx + dx, y: gy + dy) != nil { touches = true }
                            }
                        }
                        if touches { fill(outline, cell: i, cx: cx, cy: cy) }
                    }
                }
            }
            for gy in 0..<SpriteArt.height {
                for gx in 0..<SpriteArt.width {
                    if let color = SpriteArt.color(of: frame, x: gx, y: gy) {
                        fill(color, cell: i, cx: gx + 1, cy: gy + 1)
                    }
                }
            }
        }
        guard let image = ctx.makeImage() else { return nil }
        return SpriteSheet(image: image, style: style)
    }
}
