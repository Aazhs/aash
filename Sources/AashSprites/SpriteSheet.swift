import CoreGraphics

/// Every frame in one image: one cell per frame, left to right in `SpriteFrame.allCases` order.
public struct SpriteSheet {
    /// Cell size in sprite pixels: the 8 × 11 grid plus a 1-pixel margin on every side.
    public static let cellWidth = SpriteArt.width + 2
    public static let cellHeight = SpriteArt.height + 2
    public let image: CGImage
    public let style: SpriteStyle

    /// Wraps a drawn image with the style it was drawn in.
    public init(image: CGImage, style: SpriteStyle) {
        self.image = image
        self.style = style
    }

    /// One cell's width in device pixels.
    public var cellPixelWidth: Int { Self.cellWidth * style.pixelSize }
    /// One cell's height in device pixels.
    public var cellPixelHeight: Int { Self.cellHeight * style.pixelSize }

    private static func index(of frame: SpriteFrame) -> Double {
        Double(SpriteFrame.allCases.firstIndex(of: frame) ?? 0)
    }

    /// The frame's whole cell in unit coordinates, for `CALayer.contentsRect`.
    public func contentsRect(for frame: SpriteFrame) -> CGRect {
        let n = Double(SpriteFrame.allCases.count)
        return CGRect(x: Self.index(of: frame) / n, y: 0, width: 1 / n, height: 1)
    }

    /// The frame's cell without its 1-pixel margin, for non-Retina screens.
    public func contentsRectWithoutMargin(for frame: SpriteFrame) -> CGRect {
        let n = Double(SpriteFrame.allCases.count)
        let w = Double(Self.cellWidth)
        let h = Double(Self.cellHeight)
        return CGRect(x: (Self.index(of: frame) + 1 / w) / n, y: 1 / h,
                      width: (Double(SpriteArt.width) / w) / n, height: Double(SpriteArt.height) / h)
    }
}
