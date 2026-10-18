import AppKit
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Settings")

/// The menu shown when the buddy is right-clicked.
@MainActor
final class AppMenu: NSObject, NSMenuDelegate {
    let menu: NSMenu
    private let loginItem: NSMenuItem
    private let walkNowItem: NSMenuItem
    private let walkingItem: NSMenuItem
    private let settings: AppSettings
    private let onWalkNow: () -> Void
    private let onWalkingChanged: (Bool) -> Void

    init(settings: AppSettings, onWalkNow: @escaping () -> Void, onWalkingChanged: @escaping (Bool) -> Void) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let walkNowItem = NSMenuItem(title: "Walk now", action: #selector(walkNow(_:)), keyEquivalent: "")
        let walkingItem = NSMenuItem(title: "Walking", action: #selector(toggleWalking(_:)), keyEquivalent: "")
        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        let aboutItem = NSMenuItem(title: "About Aash", action: #selector(about(_:)), keyEquivalent: "")
        menu.addItem(walkNowItem)
        menu.addItem(walkingItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem(title: "Quit Aash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        self.menu = menu
        self.loginItem = loginItem
        self.walkNowItem = walkNowItem
        self.walkingItem = walkingItem
        self.settings = settings
        self.onWalkNow = onWalkNow
        self.onWalkingChanged = onWalkingChanged
        super.init()
        walkNowItem.target = self
        walkingItem.target = self
        loginItem.target = self
        aboutItem.target = self
        menu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        loginItem.state = LoginItem.isEnabled ? .on : .off
        walkNowItem.isEnabled = settings.walkingEnabled
        walkingItem.state = settings.walkingEnabled ? .on : .off
    }

    @objc private func walkNow(_ sender: NSMenuItem) {
        onWalkNow()
    }

    @objc private func toggleWalking(_ sender: NSMenuItem) {
        settings.walkingEnabled.toggle()
        onWalkingChanged(settings.walkingEnabled)
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
