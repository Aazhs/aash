/// The buddy's pixel art: the grids and palette from docs/sprites.md.
public enum SpriteArt {
    public static let width = 8
    public static let height = 11

    /// Colour for each grid character. "." is transparent and isn't in the palette.
    public static let palette: [Character: RGBA] = [
        "1": RGBA(r: 0x2a, g: 0x1b, b: 0x2e),   // hair
        "2": RGBA(r: 0xf2, g: 0xc9, b: 0xa8),   // skin
        "3": RGBA(r: 0x8f, g: 0xd3, b: 0xc9),   // hoodie
        "4": RGBA(r: 0x3f, g: 0x27, b: 0x40),   // trousers
        "5": RGBA(r: 0x1b, g: 0x11, b: 0x20),   // shoes
        "6": RGBA(r: 0x2a, g: 0x1b, b: 0x2e),   // eyes (open)
        "7": RGBA(r: 0xc0, g: 0x8f, b: 0x74),   // eyes (closed)
    ]

    /// The grid for a frame: `height` strings of `width` characters each, row 0 at the top.
    public static func rows(for frame: SpriteFrame) -> [String] {
        switch frame {
        case .idle:
            return [
                "..1111..",
                ".111111.",
                ".122221.",
                ".126262.",
                "..2222..",
                ".333333.",
                "33333333",
                "2.3333.2",
                "..4444..",
                "..4..4..",
                "..5..5..",
            ]
        case .blink:
            return [
                "..1111..",
                ".111111.",
                ".122221.",
                ".127272.",
                "..2222..",
                ".333333.",
                "33333333",
                "2.3333.2",
                "..4444..",
                "..4..4..",
                "..5..5..",
            ]
        case .walk:
            return [
                "..1111..",
                ".111111.",
                ".122221.",
                ".126262.",
                "..2222..",
                ".333333.",
                "33333333",
                "2.3333.2",
                "..4444..",
                ".4....4.",
                ".5....5.",
            ]
        case .armsUp:
            return [
                "2.1111.2",
                "21111112",
                "31222213",
                "3126262.",
                ".32222..",
                ".333333.",
                "..3333..",
                "..3333..",
                "..4444..",
                "..4..4..",
                "..5..5..",
            ]
        case .wave:
            return [
                "..1111..",
                ".111111.",
                ".122221.",
                ".126262.",
                "..2222.2",
                ".3333333",
                "3333333.",
                "2.3333..",
                "..4444..",
                "..4..4..",
                "..5..5..",
            ]
        case .waveHigh:
            return [
                "..1111.2",
                ".1111112",
                ".1222213",
                ".126262.",
                "..2222..",
                ".333333.",
                "3333333.",
                "2.3333..",
                "..4444..",
                "..4..4..",
                "..5..5..",
            ]
        case .sleep:
            return [
                "........",
                "..1111..",
                ".111111.",
                ".122221.",
                ".127272.",
                "..2222..",
                ".333333.",
                "33333333",
                "2.3333.2",
                ".444444.",
                ".55..55.",
            ]
        }
    }

    /// The colour at column `x`, row `y` (row 0 at the top), or nil when transparent or out of range.
    public static func color(of frame: SpriteFrame, x: Int, y: Int) -> RGBA? {
        let grid = rows(for: frame)
        guard y >= 0, y < grid.count else { return nil }
        let line = Array(grid[y])
        guard x >= 0, x < line.count else { return nil }
        let character = line[x]
        if character == "." { return nil }
        return palette[character]
    }
}
