/// A small seeded random generator, so behaviour is repeatable in tests.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    /// Starts the sequence from `seed`.
    public init(seed: UInt64) { state = seed }
    /// The next 64 random bits.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
