import Foundation

/// When the animation clock should fire next.
public enum ClockSchedule: Equatable, Sendable {
    /// No timer at all.
    case stopped
    /// One tick at that time.
    case once(at: Date)
    /// A tick every N seconds.
    case every(seconds: Double)
}
