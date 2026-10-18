import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var buddy: BuddyController?
    private var systemEvents: SystemEvents?
    private var appMenu: AppMenu?
    private var settings: AppSettings?
    private var stage: FreeWalkStage?

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
        stage.onClick = { [weak controller] in controller?.handle(.clicked) }
        controller.start(walkingEnabled: effectiveWalking())
        buddy = controller

        let menu = AppMenu(settings: settings,
                           isWalking: { [weak controller] in controller?.isWalking ?? false },
                           onWalkNow: { [weak controller] in controller?.handle(.walkNow) },
                           onWalkingChanged: { [weak self] _ in self?.sendWalking() },
                           reduceMotion: { [weak events] in events?.reduceMotion ?? false },
                           ownItemFrame: { [weak item] in item?.window?.frame })
        item.menu = menu.menu
        appMenu = menu

        events.onPausedChange = { [weak controller] paused in controller?.handle(.paused(paused)) }
        events.onReduceMotionChange = { [weak self] _ in self?.sendWalking() }
        events.start()
    }

    /// Reduce Motion overrides the walking setting without changing it.
    private func effectiveWalking() -> Bool {
        (settings?.walkingEnabled ?? false) && !(systemEvents?.reduceMotion ?? false)
    }

    private func sendWalking() {
        buddy?.handle(.walkingEnabled(effectiveWalking()))
    }

    func applicationWillTerminate(_ notification: Notification) {
        systemEvents?.stop()
    }
}
