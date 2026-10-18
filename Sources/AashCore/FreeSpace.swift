import Foundation

/// The menu bar along x, in screen points (AppKit coordinates).
public struct MenuBarLayout: Equatable, Sendable {
    /// The screen's left and right edges.
    public var screen: ClosedRange<Double>
    /// Right edge of the frontmost app's last menu; nil when unknown.
    public var appMenusMaxX: Double?
    /// Left edge of the leftmost status item, ours included.
    public var statusItemsMinX: Double
    /// Where the sprite's left edge is when the buddy is home.
    public var homeSpriteX: Double
    /// Ranges to keep clear, such as the camera notch.
    public var blocked: [ClosedRange<Double>]

    /// Creates a layout from measured menu bar geometry.
    public init(screen: ClosedRange<Double>, appMenusMaxX: Double?, statusItemsMinX: Double,
                homeSpriteX: Double, blocked: [ClosedRange<Double>] = []) {
        self.screen = screen
        self.appMenusMaxX = appMenusMaxX
        self.statusItemsMinX = statusItemsMinX
        self.homeSpriteX = homeSpriteX
        self.blocked = blocked
    }
}

/// A free walk, as offsets from home (negative = left).
public struct FreeWalkPlan: Equatable, Sendable {
    /// Where a walk may end. Pass it to the engine as `walkArea`.
    public var targets: ClosedRange<Double>
    /// Offsets at which the buddy is drawn. Between `visible.upperBound` and 0 it's behind icons.
    public var visible: ClosedRange<Double>
}

/// Free-walk geometry.
public enum FreeSpace {
    /// The plan for a walk, or nil when the free stretch is shorter than `minWalkDistance`.
    public static func plan(for layout: MenuBarLayout, spriteWidth: Double,
                            margin: Double = 8, minWalkDistance: Double = 24) -> FreeWalkPlan? {
        let screen = layout.screen
        // Without menu information, keep to the right half of the screen.
        let menusEnd = layout.appMenusMaxX ?? screen.lowerBound + (screen.upperBound - screen.lowerBound) / 2
        var left = menusEnd + margin
        let right = layout.statusItemsMinX - margin - spriteWidth

        let windowLow = left - margin
        let windowHigh = right + spriteWidth + margin
        for b in layout.blocked.sorted(by: { $0.lowerBound < $1.lowerBound })
        where b.lowerBound <= windowHigh && b.upperBound >= windowLow {
            left = max(left, b.upperBound + margin)
        }

        left = max(left, screen.lowerBound + margin)
        guard right - left >= minWalkDistance else { return nil }

        let visible = (left - layout.homeSpriteX)...(right - layout.homeSpriteX)
        return FreeWalkPlan(targets: visible, visible: visible)
    }
}
