import AppKit
import AashSprites

/// A sprite-sized, borderless, non-activating panel that shows the buddy above the menu bar.
@MainActor
final class WalkWindow {
    /// Called when the buddy is clicked while out walking.
    var onClick: (() -> Void)? {
        get { clickView.onClick }
        set { clickView.onClick = newValue }
    }

    /// The appearance to draw with; set it to the status button's so the same sheet is used.
    var appearance: NSAppearance? {
        get { panel.appearance }
        set { panel.appearance = newValue }
    }

    private let panel: NSPanel
    private let clickView = ClickView(frame: .zero)
    private let spriteView = SpriteLayerView(frame: .zero)
    private var shownFrame: NSRect?

    init() {
        panel = WalkPanel(contentRect: NSRect(x: 0, y: 0, width: 16, height: 24),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        // An accessory app is almost never active; the default would hide the panel straight away.
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false   // clear pixels must still take the click
        panel.isMovable = false
        panel.animationBehavior = .none
        // Status items sit at 25 and pop-up menus at 101: one above the items, below any open menu.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        clickView.frame = NSRect(x: 0, y: 0, width: 16, height: 24)
        spriteView.frame = clickView.bounds
        spriteView.autoresizingMask = [.width, .height]
        clickView.addSubview(spriteView)
        panel.contentView = clickView
    }

    /// Shows the buddy with its left edge at screen x, vertically centred on the menu bar.
    func show(_ frame: SpriteFrame, facingLeft: Bool, screenX: CGFloat, on screen: NSScreen) {
        let scale = screen.backingScaleFactor
        let barHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let height = barHeight > 0 ? barHeight : NSStatusBar.system.thickness
        let width: CGFloat = scale >= 2 ? 15 : 16   // matches SpriteLayerView.spriteWidth
        let x = (screenX * scale).rounded() / scale
        let rect = NSRect(x: x, y: screen.frame.maxY - height, width: width, height: height)
        // Move only when the position changes; most ticks change just the pose.
        if rect != shownFrame {
            panel.setFrame(rect, display: false)
            shownFrame = rect
        }
        // Order front first so the sprite is drawn at the panel's real backing scale, not a guess.
        // The empty panel is clear, so ordering it front first shows nothing.
        if !panel.isVisible { panel.orderFrontRegardless() }   // never key, never activates the app
        spriteView.show(frame, facingLeft: facingLeft, x: 0)
    }

    /// Hides the panel. It stays allocated only for the length of one walk.
    func hide() {
        if panel.isVisible { panel.orderOut(nil) }
    }
}

/// Refuses key and main status so the frontmost app keeps focus.
private final class WalkPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The panel's content: takes the click that SpriteLayerView passes through.
private final class ClickView: NSView {
    var onClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {}   // swallow, so the bar underneath doesn't react

    override func mouseUp(with event: NSEvent) {
        onClick?()
    }
}
