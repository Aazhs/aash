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
    private let freeWalkItem: NSMenuItem
    private let settings: AppSettings
    private let isWalking: () -> Bool
    private let onOpenChat: () -> Void
    private let onWalkNow: () -> Void
    private let onWalkingChanged: (Bool) -> Void
    private let onOpenSettings: () -> Void
    private let reduceMotion: () -> Bool
    private let ownItemFrame: () -> CGRect?

    init(settings: AppSettings, isWalking: @escaping () -> Bool,
         onOpenChat: @escaping () -> Void,
         onWalkNow: @escaping () -> Void, onWalkingChanged: @escaping (Bool) -> Void,
         onOpenSettings: @escaping () -> Void,
         reduceMotion: @escaping () -> Bool,
         ownItemFrame: @escaping () -> CGRect?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let chatItem = NSMenuItem(title: "Chat", action: #selector(openChat(_:)), keyEquivalent: "")
        let walkNowItem = NSMenuItem(title: "Walk now", action: #selector(walkNow(_:)), keyEquivalent: "")
        let walkingItem = NSMenuItem(title: "Walking", action: #selector(toggleWalking(_:)), keyEquivalent: "")
        let freeWalkItem = NSMenuItem(title: "Walk on the Whole Bar", action: #selector(toggleFreeWalk(_:)), keyEquivalent: "")
        freeWalkItem.indentationLevel = 1
        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        let aboutItem = NSMenuItem(title: "About Aash", action: #selector(about(_:)), keyEquivalent: "")
        menu.addItem(chatItem)
        menu.addItem(.separator())
        menu.addItem(walkNowItem)
        menu.addItem(walkingItem)
        menu.addItem(freeWalkItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(aboutItem)
        let reportItem = NSMenuItem(title: "Copy Menu Bar Report", action: #selector(copyReport(_:)), keyEquivalent: "")
        reportItem.isAlternate = true
        reportItem.keyEquivalentModifierMask = [.option]
        menu.addItem(reportItem)
        menu.addItem(NSMenuItem(title: "Quit Aash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        self.menu = menu
        self.loginItem = loginItem
        self.walkNowItem = walkNowItem
        self.walkingItem = walkingItem
        self.freeWalkItem = freeWalkItem
        self.settings = settings
        self.isWalking = isWalking
        self.onOpenChat = onOpenChat
        self.onWalkNow = onWalkNow
        self.onWalkingChanged = onWalkingChanged
        self.onOpenSettings = onOpenSettings
        self.reduceMotion = reduceMotion
        self.ownItemFrame = ownItemFrame
        super.init()
        chatItem.target = self
        walkNowItem.target = self
        walkingItem.target = self
        freeWalkItem.target = self
        loginItem.target = self
        settingsItem.target = self
        aboutItem.target = self
        reportItem.target = self
        menu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        loginItem.state = LoginItem.isEnabled ? .on : .off
        let still = reduceMotion()
        walkNowItem.isEnabled = settings.walkingEnabled && !still && !isWalking()
        walkingItem.title = still ? "Walking (off for Reduce Motion)" : "Walking"
        walkingItem.isEnabled = !still
        walkingItem.state = settings.walkingEnabled ? .on : .off
        freeWalkItem.state = settings.freeWalkEnabled ? .on : .off
        freeWalkItem.isEnabled = settings.walkingEnabled && !still
    }

    @objc private func openChat(_ sender: NSMenuItem) {
        onOpenChat()
    }

    @objc private func walkNow(_ sender: NSMenuItem) {
        onWalkNow()
    }

    @objc private func toggleWalking(_ sender: NSMenuItem) {
        settings.walkingEnabled.toggle()
        onWalkingChanged(settings.walkingEnabled)
    }

    @objc private func toggleFreeWalk(_ sender: NSMenuItem) {
        settings.freeWalkEnabled.toggle()
        // Takes effect from the next walk; without permission each walk falls back to stretching.
        if settings.freeWalkEnabled && !MenuBarScanner.isTrusted { MenuBarScanner.requestTrust() }
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            log.error("Open at Login failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        onOpenSettings()
    }

    @objc private func about(_ sender: NSMenuItem) {
        NSApp.activate()   // an accessory app must activate, or the panel opens behind other windows
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func copyReport(_ sender: NSMenuItem) {
        let text: String
        if MenuBarScanner.isTrusted {
            text = MenuBarScanner.report(MenuBarScanner.scan(), ownItem: ownItemFrame())
        } else {
            MenuBarScanner.requestTrust()
            text = "Accessibility isn't allowed yet."
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
