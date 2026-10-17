import AppKit
import AashCore

@MainActor
final class AnimationClock {
    var onTick: (() -> Void)?
    private var timer: Timer?
    private(set) var schedule: ClockSchedule = .stopped

    func apply(_ newSchedule: ClockSchedule) {
        guard newSchedule != schedule else { return }
        schedule = newSchedule
        timer?.invalidate()
        timer = nil
        let made: Timer
        switch newSchedule {
        case .stopped:
            return
        case .every(let seconds):
            made = Timer(timeInterval: seconds, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.onTick?() }
            }
            made.tolerance = seconds * 0.2
        case .once(let date):
            made = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.schedule = .stopped
                    self?.onTick?()
                }
            }
            made.tolerance = 0.5
        }
        RunLoop.main.add(made, forMode: .common)   // .common: keeps firing while a menu is open
        timer = made
    }
}
