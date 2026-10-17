/// A colour with 8-bit channels, not premultiplied.
public struct RGBA: Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    /// Creates a colour from its channels; alpha defaults to fully opaque.
    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// Parses "#rrggbb" or "rrggbb" (either case). Returns nil for anything else.
    public init?(hex: String) {
        var digits = Substring(hex)
        if digits.first == "#" { digits = digits.dropFirst() }
        guard digits.count == 6 else { return nil }
        let chars = Array(digits)
        guard chars.allSatisfy(\.isHexDigit) else { return nil }
        func channel(_ index: Int) -> UInt8? {
            UInt8(String(chars[index..<index + 2]), radix: 16)
        }
        guard let r = channel(0), let g = channel(2), let b = channel(4) else { return nil }
        self.init(r: r, g: g, b: b)
    }
}
