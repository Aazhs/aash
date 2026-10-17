import AashCore
import AashSprites

extension SpriteFrame {
    /// The sheet frame that shows an engine pose.
    init(_ pose: Pose) {
        switch pose {
        case .idle: self = .idle
        case .blink: self = .blink
        case .walk: self = .walk
        case .armsUp: self = .armsUp
        case .wave: self = .wave
        case .waveHigh: self = .waveHigh
        case .sleep: self = .sleep
        }
    }
}
