import AppKit
import AashCore

@MainActor
final class StatusItemController: NSObject {
    /// The item's width while the buddy is home, in points.
    static let homeLength: CGFloat = 22
    let spriteView = SpriteLayerView(frame: .zero)
    /// Called on a left click.
    var onLeftClick: (() -> Void)?
    /// Shown on a right click.
    var menu: NSMenu?
    private let item = NSStatusBar.system.statusItem(withLength: StatusItemController.homeLength)

    override init() {
        super.init()
        guard let button = item.button else { return }
        button.image = nil
        button.title = ""
        button.toolTip = "Aash \(AashCore.version)"
        button.setAccessibilityTitle("Aash")
        spriteView.frame = button.bounds
        spriteView.autoresizingMask = [.width, .height]
        button.addSubview(spriteView)
        button.target = self
        button.action = #selector(clicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// The item's width in points. Setting it widens or narrows the item to the left.
    var length: CGFloat {
        get { item.length }
        set { item.length = newValue }
    }

    /// The status bar button, which the chat popover points at.
    var button: NSStatusBarButton? { item.button }

    /// The window that hosts the item, for occlusion and its position on screen.
    var window: NSWindow? { item.button?.window }

    /// The sprite's left edge in button coordinates, for an offset from home (docs/menubar.md#stretch-walk).
    func spriteX(offset: Double) -> CGFloat {
        // Uses `length`, not the button's bounds: bounds can lag one layout pass behind a width change.
        (length - Self.homeLength) + (Self.homeLength - spriteView.spriteWidth) / 2 + offset
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp, let menu {
            item.menu = menu
            sender.performClick(nil)   // shows the menu
            item.menu = nil            // left clicks stay ours
        } else {
            onLeftClick?()
        }
    }
}
