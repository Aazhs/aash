import Foundation

/// The user's settings, stored in UserDefaults (keys: docs/architecture.md#settings-keys).
@MainActor
final class AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Whether the buddy goes for walks. Default true.
    var walkingEnabled: Bool {
        get { defaults.object(forKey: "walkingEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "walkingEnabled") }
    }

    /// How far a stretch walk may go, in points. Default 120; reads and writes are clamped to 24...240.
    var walkDistance: Double {
        get { min(max(defaults.object(forKey: "walkDistance") as? Double ?? 120, 24), 240) }
        set { defaults.set(min(max(newValue, 24), 240), forKey: "walkDistance") }
    }

    /// Whether walks may leave the icon and use the free part of the bar. Default false.
    var freeWalkEnabled: Bool {
        get { defaults.object(forKey: "freeWalkEnabled") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "freeWalkEnabled") }
    }
}
