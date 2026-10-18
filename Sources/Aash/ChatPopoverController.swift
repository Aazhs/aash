import AppKit
import Darwin
import AashAI
import AashCore

/// Owns the chat popover. Views exist only while it is open (docs/performance.md, rule 8).
@MainActor
final class ChatPopoverController: NSObject, NSPopoverDelegate {
    private let anchor: () -> NSView?
    private let settings: AppSettings
    private let reminders: RemindersService
    private let keychain: KeychainStore
    private let openSettings: () -> Void
    private let onEvent: (BuddyEvent) -> Void
    private var popover: NSPopover?
    private var viewController: ChatViewController?

    /// `anchor` returns the view the popover points at. `openSettings` is what the "Open Settings"
    /// button does. `onEvent` receives `.chatOpened`, `.chatClosed` and `.replyArrived`.
    init(anchor: @escaping () -> NSView?, settings: AppSettings, reminders: RemindersService,
         keychain: KeychainStore = KeychainStore(),
         openSettings: @escaping () -> Void,
         onEvent: @escaping (BuddyEvent) -> Void) {
        self.anchor = anchor
        self.settings = settings
        self.reminders = reminders
        self.keychain = keychain
        self.openSettings = openSettings
        self.onEvent = onEvent
        super.init()
    }

    /// True while the popover is on screen.
    var isShown: Bool { popover?.isShown ?? false }

    /// Opens the popover, or closes it if it is open.
    func toggle() {
        isShown ? close() : show()
    }

    /// Opens the popover. Does nothing if it is already open.
    func show() {
        guard popover == nil, let anchor = anchor() else { return }
        let stored = (try? keychain.read(SettingsWindowController.keyAccount)) ?? nil
        let key = (stored?.isEmpty ?? true) ? nil : stored
        let provider = GeminiProvider(apiKey: key, model: settings.chatModel)
        let intent = ReminderIntent(reminders: reminders, provider: provider)
        let viewController = ChatViewController(
            provider: provider, reminders: intent, hasKey: key != nil,
            openSettings: { [weak self] in
                self?.close()
                self?.openSettings()
            },
            onReply: { [weak self] in self?.onEvent(.replyArrived) })
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 420)
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = viewController
        self.popover = popover
        self.viewController = viewController
        NSApp.activate()
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        onEvent(.chatOpened)
    }

    /// Closes the popover.
    func close() {
        popover?.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        viewController?.cancel()
        popover?.contentViewController = nil
        popover = nil
        viewController = nil
        onEvent(.chatClosed)
        Self.releaseFreedMemory()
    }

    /// Returns freed malloc pages to the system once the chat's objects are gone.
    private static func releaseFreedMemory() {
        // The views are freed when the autorelease pool drains at the end of this run-loop turn,
        // so the relief has to run on the next turn.
        RunLoop.main.perform { _ = malloc_zone_pressure_relief(nil, 0) }
    }
}
