import AashCore
import AashSprites

/// Walks inside the status item, widened to the left (docs/menubar.md#stretch-walk).
@MainActor
final class StretchStage: WalkStage {
    private let statusItem: StatusItemController
    private let distance: @MainActor () -> Double

    /// `distance` is read at the start of each walk, in points.
    init(statusItem: StatusItemController, distance: @escaping @MainActor () -> Double) {
        self.statusItem = statusItem
        self.distance = distance
    }

    func prepare() async -> ClosedRange<Double>? {
        let d = distance()
        statusItem.length = StatusItemController.homeLength + d
        return -d ... 0
    }

    func show(_ output: BuddyOutput) {
        statusItem.spriteView.show(SpriteFrame(output.pose), facingLeft: output.facingLeft,
                                   x: statusItem.spriteX(offset: output.offset))
    }

    func finish() {
        statusItem.length = StatusItemController.homeLength
    }
}
