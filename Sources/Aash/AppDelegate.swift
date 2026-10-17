import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var buddy: BuddyController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = StatusItemController()
        // T06 replaces this menu.
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Aash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item

        let controller = BuddyController(statusItem: item)
        controller.start()
        buddy = controller
    }
}
