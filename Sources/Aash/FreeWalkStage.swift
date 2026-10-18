import AashCore
import AashSprites
import AppKit
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Walk")

/// Walks over the free part of the menu bar when allowed; otherwise delegates to the stretch stage.
@MainActor
final class FreeWalkStage: WalkStage {
    private enum Mode { case idle, fallback, free }

    private let statusItem: StatusItemController
    private let fallback: StretchStage
    private let settings: AppSettings
    // Decided once per walk in prepare(); the menu toggle may flip mid-walk.
    private var mode: Mode = .idle
    private var plan: FreeWalkPlan?
    private var homeScreenX: CGFloat = 0
    private var screen: NSScreen?
    private var window: WalkWindow?
    private var tokens: [NSObjectProtocol] = []

    var onRoomChanged: ((ClosedRange<Double>?) -> Void)?
    /// Called when the buddy is clicked while out in the walk window.
    var onClick: (() -> Void)?

    init(statusItem: StatusItemController, fallback: StretchStage, settings: AppSettings) {
        self.statusItem = statusItem
        self.fallback = fallback
        self.settings = settings
        fallback.onRoomChanged = { [weak self] area in self?.onRoomChanged?(area) }
    }

    func prepare() async -> ClosedRange<Double>? {
        guard settings.freeWalkEnabled else { return await useFallback() }
        guard MenuBarScanner.isTrusted else {
            _ = reject("Accessibility not allowed")
            return await useFallback()
        }
        guard let found = measure() else { return await useFallback() }
        log.info("free walk: targets \(found.targets.lowerBound, privacy: .public) … \(found.targets.upperBound, privacy: .public)")
        mode = .free
        plan = found
        let walkWindow = WalkWindow()
        walkWindow.onClick = { [weak self] in self?.onClick?() }
        walkWindow.appearance = statusItem.spriteView.effectiveAppearance
        window = walkWindow
        observe()
        return found.targets
    }

    func show(_ output: BuddyOutput) {
        switch mode {
        case .fallback:
            fallback.show(output)
        case .idle, .free:
            let frame = SpriteFrame(output.pose)
            if output.offset == 0 || mode == .idle {
                window?.hide()
                statusItem.spriteView.isHidden = false
                statusItem.spriteView.show(frame, facingLeft: output.facingLeft, x: statusItem.spriteX(offset: 0))
            } else if let plan, let screen, plan.visible.contains(output.offset) {
                statusItem.spriteView.isHidden = true
                window?.show(frame, facingLeft: output.facingLeft,
                             screenX: homeScreenX + output.offset, on: screen)
            } else {
                // Behind other status items: nothing to draw.
                statusItem.spriteView.isHidden = true
                window?.hide()
            }
        }
    }

    func finish() {
        for token in tokens {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            NotificationCenter.default.removeObserver(token)
        }
        tokens.removeAll()
        window?.hide()
        window = nil
        plan = nil
        screen = nil
        mode = .idle
        statusItem.spriteView.isHidden = false
        fallback.finish()
    }

    private func useFallback() async -> ClosedRange<Double>? {
        mode = .fallback
        return await fallback.prepare()
    }

    private func observe() {
        guard tokens.isEmpty else { return }
        tokens.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rescan() }
        })
        // Entering a full-screen Space mid-walk: the bar may be gone, so the rescan hides the buddy.
        tokens.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rescan() }
        })
        tokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rescan() }
        })
    }

    private func rescan() {
        guard mode == .free else { return }
        // A nil plan hides the buddy until it's home: the old free space may now be covered.
        plan = measure()
        window?.appearance = statusItem.spriteView.effectiveAppearance
        onRoomChanged?(plan?.targets)
    }

    /// Scans the bar and plans a walk; nil (with the reason logged) when the scan isn't believable.
    private func measure() -> FreeWalkPlan? {
        guard let itemWindow = statusItem.window, let screen = itemWindow.screen else {
            return reject("status item has no window or screen")
        }
        let scan = MenuBarScanner.scan()
        let barMinY = screen.visibleFrame.maxY - 1
        let onBar: (MenuBarElement) -> Bool = { e in
            e.frame.midX >= screen.frame.minX && e.frame.midX <= screen.frame.maxX
                && e.frame.maxY > barMinY && e.frame.width < screen.frame.width / 2
        }
        let menus = scan.appMenus.filter(onBar)
        let extras = scan.extras.filter(onBar)
        guard !menus.isEmpty else { return reject("no app menus") }
        guard !(menus + extras).contains(where: { $0.frame.width <= 0 || $0.frame.height <= 0 }) else {
            return reject("zero-size frame")
        }
        let own = itemWindow.frame
        guard extras.contains(where: { own.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }) else {
            return reject("own item missing from scan")
        }
        let menusMaxX = menus.map(\.frame.maxX).max() ?? screen.frame.minX
        let itemsMinX = min(extras.map(\.frame.minX).min() ?? own.minX, own.minX)
        guard menusMaxX < itemsMinX else { return reject("menus reach the status items") }

        let inWindow = statusItem.spriteView.convert(NSPoint(x: statusItem.spriteX(offset: 0), y: 0), to: nil)
        let home = itemWindow.convertPoint(toScreen: inWindow).x
        // Nothing blocked: the only Mac this runs on (MacBook Air M1) has no notch.
        let layout = MenuBarLayout(screen: Double(screen.frame.minX)...Double(screen.frame.maxX),
                                   appMenusMaxX: Double(menusMaxX), statusItemsMinX: Double(itemsMinX),
                                   homeSpriteX: Double(home))
        guard let found = FreeSpace.plan(for: layout, spriteWidth: Double(statusItem.spriteView.spriteWidth)) else {
            return reject("free space too short")
        }
        homeScreenX = home
        self.screen = screen
        return found
    }

    private func reject(_ reason: String) -> FreeWalkPlan? {
        log.info("free walk off for this walk: \(reason, privacy: .public)")
        return nil
    }
}
