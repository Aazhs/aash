import AashCore
import AashSprites
import AppKit

/// Walks inside the status item, widened to the left (docs/menubar.md#stretch-walk).
@MainActor
final class StretchStage: WalkStage {
    private let statusItem: StatusItemController
    private let distance: @MainActor () -> Double
    private var screenObserver: NSObjectProtocol?

    var onRoomChanged: ((ClosedRange<Double>?) -> Void)?

    /// `distance` is read at the start of each walk, in points.
    init(statusItem: StatusItemController, distance: @escaping @MainActor () -> Double) {
        self.statusItem = statusItem
        self.distance = distance
    }

    func prepare() async -> ClosedRange<Double>? {
        // window.screen is nil while the bar is hidden; no walk then.
        guard let window = statusItem.window, let screen = window.screen else { return nil }
        guard window.frame.minX >= screen.frame.minX, window.frame.maxX <= screen.frame.maxX else { return nil }
        // Keep the left 55% of the screen free for app menus.
        let limit = screen.frame.minX + screen.frame.width * 0.45
        let d = min(distance(), window.frame.minX - limit - 8)
        if d < 24 { return nil }
        statusItem.length = StatusItemController.homeLength + d
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.onRoomChanged?(nil) }
            }
        }
        return -d ... 0
    }

    func show(_ output: BuddyOutput) {
        statusItem.spriteView.show(SpriteFrame(output.pose), facingLeft: output.facingLeft,
                                   x: statusItem.spriteX(offset: output.offset))
    }

    func finish() {
        if let token = screenObserver {
            NotificationCenter.default.removeObserver(token)
            screenObserver = nil
        }
        statusItem.length = StatusItemController.homeLength
    }
}
