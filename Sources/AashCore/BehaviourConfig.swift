import Foundation

/// Timings for the behaviour engine. Defaults are docs/behaviour.md#timings.
public struct BehaviourConfig: Equatable, Sendable {
    public var blinkEvery: ClosedRange<Double> = 3...6
    public var blinkLength: Double = 0.15
    public var walkEvery: ClosedRange<Double> = 300...900
    public var walkSpeed: Double = 18
    public var minWalkDistance: Double = 24
    public var walkFPS: Double = 8
    public var restLength: ClosedRange<Double> = 2...6
    public var waveLength: Double = 6
    public var waveLead: Double = 5
    public var waveFPS: Double = 4
    public var cheerLength: Double = 0.6
    public var areaTimeout: Double = 2
    public var afterChatDelay: Double = 60
    public var nightStartHour: Int = 23
    public var nightEndHour: Int = 7
    public var maxStep: Double = 0.5
    public var calendar: Calendar = .current
    /// The defaults.
    public init() {}
    /// The default timings.
    public static let standard = BehaviourConfig()
}
