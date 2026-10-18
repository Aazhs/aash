import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var buddy: BuddyController?
    private var systemEvents: SystemEvents?
    private var appMenu: AppMenu?
    private var settings: AppSettings?
    private var stage: StretchStage?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = StatusItemController()
        statusItem = item
        let settings = AppSettings()
        self.settings = settings
        let stage = StretchStage(statusItem: item, distance: { [weak settings] in settings?.walkDistance ?? 120 })
        self.stage = stage

        let controller = BuddyController(statusItem: item, stage: stage)
        controller.start(walkingEnabled: settings.walkingEnabled)
        buddy = controller

        let menu = AppMenu(settings: settings,
                           isWalking: { [weak controller] in controller?.isWalking ?? false },
                           onWalkNow: { [weak controller] in controller?.handle(.walkNow) },
                           onWalkingChanged: { [weak controller] on in controller?.handle(.walkingEnabled(on)) })
        item.menu = menu.menu
        appMenu = menu

        let events = SystemEvents(statusWindow: { [weak item] in item?.window })
        events.onPausedChange = { [weak controller] paused in controller?.handle(.paused(paused)) }
        events.start()
        systemEvents = events
    }

    func applicationWillTerminate(_ notification: Notification) {
        systemEvents?.stop()
    }
}
