import AppKit
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Settings")

/// The menu shown when the buddy is right-clicked.
@MainActor
final class AppMenu: NSObject, NSMenuDelegate {
    let menu: NSMenu
    private let loginItem: NSMenuItem

    override init() {
        let menu = NSMenu()
        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        let aboutItem = NSMenuItem(title: "About Aash", action: #selector(about(_:)), keyEquivalent: "")
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem(title: "Quit Aash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        self.menu = menu
        self.loginItem = loginItem
        super.init()
        loginItem.target = self
        aboutItem.target = self
        menu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            log.error("Open at Login failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @objc private func about(_ sender: NSMenuItem) {
        NSApp.activate()   // an accessory app must activate, or the panel opens behind other windows
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
