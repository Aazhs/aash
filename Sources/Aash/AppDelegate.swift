import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var buddy: BuddyController?
    private var systemEvents: SystemEvents?
    private var appMenu: AppMenu?
    private var settings: AppSettings?
    private var stage: FreeWalkStage?
    private var settingsWindow: SettingsWindowController?
    private var chat: ChatPopoverController?
    private var reminders: RemindersService?
    private var scheduler: ReminderScheduler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = StatusItemController()
        statusItem = item
        let settings = AppSettings()
        self.settings = settings
        let stretch = StretchStage(statusItem: item, distance: { [weak settings] in settings?.walkDistance ?? 120 })
        let stage = FreeWalkStage(statusItem: item, fallback: stretch, settings: settings)
        self.stage = stage

        let events = SystemEvents(statusWindow: { [weak item] in item?.window })
        systemEvents = events

        let controller = BuddyController(statusItem: item, stage: stage)
        controller.start(walkingEnabled: effectiveWalking())
        buddy = controller
        let reminders = RemindersService()
        self.reminders = reminders
        let scheduler = ReminderScheduler(reminders: reminders, send: { [weak controller] in controller?.handle($0) })
        self.scheduler = scheduler
        reminders.onChange = { [weak scheduler] in scheduler?.refresh() }
        controller.onReminderWave = { [weak scheduler] in scheduler?.refresh() }
        chat = ChatPopoverController(
            anchor: { [weak item] in item?.button }, settings: settings, reminders: reminders,
            openSettings: { [weak self] in self?.openSettings() },
            onEvent: { [weak controller] in controller?.handle($0) })
        // After `start`, which also sets onLeftClick.
        item.onLeftClick = { [weak self] in self?.buddyClicked() }
        stage.onClick = { [weak self] in self?.buddyClicked() }

        let menu = AppMenu(settings: settings,
                           isWalking: { [weak controller] in controller?.isWalking ?? false },
                           onOpenChat: { [weak self] in self?.chat?.show() },
                           onWalkNow: { [weak controller] in controller?.handle(.walkNow) },
                           onWalkingChanged: { [weak self] _ in self?.sendWalking() },
                           onOpenSettings: { [weak self] in self?.openSettings() },
                           reduceMotion: { [weak events] in events?.reduceMotion ?? false },
                           ownItemFrame: { [weak item] in item?.window?.frame },
                           remindersToday: { [weak scheduler] in scheduler?.countToday() ?? 0 })
        item.menu = menu.menu
        appMenu = menu

        events.onPausedChange = { [weak controller, weak scheduler] paused in
            controller?.handle(.paused(paused))
            if !paused { scheduler?.refresh() }   // a reminder may have been due while paused
        }
        events.onReduceMotionChange = { [weak self] _ in self?.sendWalking() }
        events.start()
        scheduler.refresh()
    }

    private func buddyClicked() {
        buddy?.handle(.clicked)
        chat?.toggle()
    }

    private func openSettings() {
        guard let settings else { return }
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                settings: settings,
                reduceMotion: { [weak self] in self?.systemEvents?.reduceMotion ?? false },
                onWalkingChanged: { [weak self] in self?.sendWalking() },
                onClose: { [weak self] in self?.settingsWindow = nil })
        }
        settingsWindow?.show()
    }

    /// Reduce Motion overrides the walking setting without changing it.
    private func effectiveWalking() -> Bool {
        (settings?.walkingEnabled ?? false) && !(systemEvents?.reduceMotion ?? false)
    }

    private func sendWalking() {
        buddy?.handle(.walkingEnabled(effectiveWalking()))
    }

    /// An accessory app shows nothing when launched a second time, so open the chat instead.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        chat?.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        systemEvents?.stop()
    }
}
