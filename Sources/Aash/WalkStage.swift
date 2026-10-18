import AashCore

/// Where a walk happens. BuddyController uses one stage at a time.
@MainActor
protocol WalkStage: AnyObject {
    /// Makes room for a walk; returns where it may end, as offsets from home, or nil for no room.
    func prepare() async -> ClosedRange<Double>?
    /// Draws the buddy while a walk is on.
    func show(_ output: BuddyOutput)
    /// The walk is over: gives the room back. Safe to call more than once.
    func finish()
}
