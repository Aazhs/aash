import AppKit
import AashCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Placeholder until T04 draws the sprite.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "◦"
        item.button?.toolTip = "Aash \(AashCore.version)"

        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Aash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
}
