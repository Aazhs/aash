import AppKit
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "System")

/// Watches for the Mac becoming unwatched: screen asleep, locked, Low Power Mode, buddy hidden.
@MainActor
final class SystemEvents {
    /// Why the buddy is paused right now.
    enum Reason: String, CaseIterable {
        case screenAsleep, locked, lowPower, hidden
    }

    /// Called with the new value whenever `isPaused` changes.
    var onPausedChange: ((Bool) -> Void)?
    /// The reasons that currently apply.
    private(set) var reasons: Set<Reason> = []
    /// True while any reason applies.
    var isPaused: Bool { !reasons.isEmpty }

    /// Called with the new value whenever Reduce Motion changes.
    var onReduceMotionChange: ((Bool) -> Void)?
    /// True while the user has Reduce Motion on.
    private(set) var reduceMotion: Bool

    private let statusWindow: @MainActor () -> NSWindow?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    /// `statusWindow` returns the status item's window when asked; it may be nil early on.
    init(statusWindow: @escaping @MainActor () -> NSWindow?) {
        self.statusWindow = statusWindow
        self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Starts observing, and reads Low Power Mode's current state.
    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.set(.screenAsleep, true) }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.set(.screenAsleep, false) }

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.set(.locked, true) }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.set(.locked, false) }

        observe(NotificationCenter.default, .NSProcessInfoPowerStateDidChange) {
            $0.set(.lowPower, ProcessInfo.processInfo.isLowPowerModeEnabled)
        }

        observe(workspace, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification) {
            $0.setReduceMotion(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        }

        if let window = statusWindow() {
            observe(NotificationCenter.default, NSWindow.didChangeOcclusionStateNotification, object: window) {
                $0.set(.hidden, !window.occlusionState.contains(.visible))
            }
        } else {
            log.error("status item window is nil; hidden detection off")
        }

        set(.lowPower, ProcessInfo.processInfo.isLowPowerModeEnabled)
        setReduceMotion(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    /// Removes every observer.
    func stop() {
        for (center, token) in tokens {
            center.removeObserver(token)
        }
        tokens.removeAll()
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        object: AnyObject? = nil,
        _ handler: @escaping @MainActor (SystemEvents) -> Void
    ) {
        let token = center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { handler(self) }
            }
        }
        tokens.append((center, token))
    }

    private func set(_ reason: Reason, _ on: Bool) {
        let before = isPaused
        let changed = on ? reasons.insert(reason).inserted : reasons.remove(reason) != nil
        if changed {
            log.debug("paused reason \(reason.rawValue, privacy: .public): \(on ? "on" : "off", privacy: .public)")
        }
        if isPaused != before {
            onPausedChange?(isPaused)
        }
    }

    private func setReduceMotion(_ on: Bool) {
        guard on != reduceMotion else { return }
        reduceMotion = on
        log.debug("reduce motion: \(on ? "on" : "off", privacy: .public)")
        onReduceMotionChange?(on)
    }
}
