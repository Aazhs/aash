import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var buddy: BuddyController?
    private var systemEvents: SystemEvents?

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

        let events = SystemEvents(statusWindow: { [weak item] in item?.window })
        events.onPausedChange = { [weak controller] paused in controller?.handle(.paused(paused)) }
        events.start()
        systemEvents = events
    }

    func applicationWillTerminate(_ notification: Notification) {
        systemEvents?.stop()
    }
}
