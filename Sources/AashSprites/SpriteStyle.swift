/// How a sprite sheet is drawn.
public struct SpriteStyle: Hashable, Sendable {
    /// Device pixels per sprite pixel; a whole number, at least 1.
    public var pixelSize: Int
    /// The outline colour for dark menu bars, or nil for no outline.
    public var outline: RGBA?

    /// Creates a style; `pixelSize` is clamped to at least 1.
    public init(pixelSize: Int, outline: RGBA? = nil) {
        self.pixelSize = max(1, pixelSize)
        self.outline = outline
    }

    /// The outline colour from docs/sprites.md: solid #ede6f2.
    public static let outlineColor = RGBA(r: 0xed, g: 0xe6, b: 0xf2, a: 255)
    /// Retina, light menu bar.
    public static let light = SpriteStyle(pixelSize: 4)
    /// Retina, dark menu bar (no outline, same as light).
    public static let dark = SpriteStyle(pixelSize: 4)
    /// Non-Retina screens (always without outline).
    public static let lowResolution = SpriteStyle(pixelSize: 2)
}
