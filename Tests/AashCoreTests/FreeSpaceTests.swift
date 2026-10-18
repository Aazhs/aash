import Testing
@testable import AashCore

@Suite struct FreeSpaceTests {
    private func layout(menus: Double? = 420, items: Double = 900,
                        blocked: [ClosedRange<Double>] = []) -> MenuBarLayout {
        MenuBarLayout(screen: 0...1440, appMenusMaxX: menus, statusItemsMinX: items,
                      homeSpriteX: 1021.5, blocked: blocked)
    }

    private func plan(_ l: MenuBarLayout) -> FreeWalkPlan? {
        FreeSpace.plan(for: l, spriteWidth: 15, margin: 8)
    }

    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0001 }

    @Test func typicalBar() throws {
        let p = try #require(plan(layout()))
        #expect(close(p.visible.lowerBound, 428 - 1021.5))
        #expect(close(p.visible.upperBound, 877 - 1021.5))
        #expect(p.targets == p.visible)
    }

    @Test func unknownMenusUseTheRightHalf() throws {
        let p = try #require(plan(layout(menus: nil)))
        #expect(close(p.visible.lowerBound, 728 - 1021.5))
    }

    @Test func crowdedBarHasNoPlan() {
        #expect(plan(layout(items: 450)) == nil)
    }

    @Test func notchSplitsTheBar() throws {
        let p = try #require(plan(layout(items: 1000, blocked: [700...880])))
        #expect(close(p.visible.lowerBound, 888 - 1021.5))
        #expect(close(p.visible.upperBound, 977 - 1021.5))
    }

    @Test func notchOutOfTheWay() throws {
        let p = try #require(plan(layout(blocked: [100...200])))
        #expect(p == plan(layout()))
    }

    @Test func ourItemIsLeftmost() throws {
        let p = try #require(plan(layout(items: 1010)))
        #expect(close(p.visible.upperBound, 987 - 1021.5))
    }

    @Test func tinyGapIsNil() {
        #expect(plan(layout(menus: 860)) == nil)
    }
}
