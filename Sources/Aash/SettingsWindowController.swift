import AppKit
import AashAI
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Settings")

/// The settings window: Gemini key, chat model, walking and open at login. Built on open, freed on close.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    /// The Keychain account that holds the Gemini key (docs/ai.md#keychain).
    static let keyAccount = "gemini"

    private let settings: AppSettings
    private let keychain: KeychainStore
    private let reduceMotion: () -> Bool
    private let onWalkingChanged: () -> Void
    private let onClose: () -> Void
    private var window: NSWindow?

    private var keyField: NSSecureTextField?
    private var statusLabel: NSTextField?
    private var modelField: NSTextField?
    private var freeWalkBox: NSButton?
    private var loginBox: NSButton?
    private var distanceSlider: NSSlider?

    init(settings: AppSettings, keychain: KeychainStore = KeychainStore(),
         reduceMotion: @escaping () -> Bool,
         onWalkingChanged: @escaping () -> Void,
         onClose: @escaping () -> Void) {
        self.settings = settings
        self.keychain = keychain
        self.reduceMotion = reduceMotion
        self.onWalkingChanged = onWalkingChanged
        self.onClose = onClose
        super.init()
    }

    /// Builds the window if needed, activates the app and brings the window to the front.
    func show() {
        if window == nil { window = makeWindow() }
        NSApp.activate()   // an accessory app must activate, or the window opens behind other windows
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        window = nil
        onClose()
    }

    // MARK: Building

    private func makeWindow() -> NSWindow {
        let still = reduceMotion()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        stack.addArrangedSubview(makeKeyRow())

        let model = NSTextField(string: settings.chatModel)
        model.placeholderString = AppSettings.defaultChatModel
        model.delegate = self
        model.widthAnchor.constraint(equalToConstant: 260).isActive = true
        modelField = model
        stack.addArrangedSubview(makeRow(title: "Model", control: model))

        let walking = NSButton(checkboxWithTitle: "Walking", target: self, action: #selector(walkingToggled(_:)))
        walking.state = settings.walkingEnabled ? .on : .off
        walking.isEnabled = !still
        stack.addArrangedSubview(walking)

        let free = NSButton(checkboxWithTitle: "Walk on the whole bar", target: self, action: #selector(freeWalkToggled(_:)))
        free.state = settings.freeWalkEnabled ? .on : .off
        free.isEnabled = settings.walkingEnabled && !still
        freeWalkBox = free
        let freeRow = NSStackView(views: [free])
        freeRow.edgeInsets = NSEdgeInsets(top: 0, left: 18, bottom: 0, right: 0)
        stack.addArrangedSubview(freeRow)

        let login = NSButton(checkboxWithTitle: "Open at login", target: self, action: #selector(loginToggled(_:)))
        login.state = LoginItem.isEnabled ? .on : .off
        loginBox = login
        stack.addArrangedSubview(login)

        let slider = NSSlider(value: settings.walkDistance, minValue: 24, maxValue: 240,
                              target: self, action: #selector(distanceChanged(_:)))
        slider.isContinuous = false
        slider.isEnabled = settings.walkingEnabled && !still
        slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        distanceSlider = slider
        stack.addArrangedSubview(makeRow(title: "Walk distance", control: slider))

        if still {
            stack.addArrangedSubview(smallLabel("Walking is off while Reduce Motion is on."))
        }

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 100),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Aash Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = stack
        window.setContentSize(NSSize(width: 420, height: stack.fittingSize.height))
        window.center()
        return window
    }

    private func makeKeyRow() -> NSView {
        let field = NSSecureTextField()
        field.placeholderString = "Paste your key"
        field.widthAnchor.constraint(equalToConstant: 200).isActive = true
        keyField = field
        let save = NSButton(title: "Save", target: self, action: #selector(saveKey(_:)))
        let remove = NSButton(title: "Remove", target: self, action: #selector(removeKey(_:)))
        let row = makeRow(title: "Gemini key", control: field)
        row.addArrangedSubview(save)
        row.addArrangedSubview(remove)

        let status = smallLabel("")
        statusLabel = status
        showSavedStatus()

        let link = NSButton(title: "Get a free key at aistudio.google.com", target: self, action: #selector(openKeyPage(_:)))
        link.bezelStyle = .inline
        link.isBordered = false
        link.contentTintColor = .linkColor

        let column = NSStackView(views: [row, status, link])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        return column
    }

    private func makeRow(title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline
        return row
    }

    private func smallLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        return label
    }

    // MARK: Key

    private func savedStatus(_ key: String) -> String {
        "Saved: •••• \(key.suffix(4))"
    }

    private func showSavedStatus() {
        do {
            if let key = try keychain.read(Self.keyAccount) {
                statusLabel?.stringValue = savedStatus(key)
            } else {
                statusLabel?.stringValue = "No key saved."
            }
        } catch {
            log.error("Keychain read failed: \(String(describing: error), privacy: .public)")
            statusLabel?.stringValue = "Couldn't read the Keychain."
        }
    }

    @objc private func saveKey(_ sender: NSButton) {
        let key = (keyField?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            statusLabel?.stringValue = "Paste a key first."
            return
        }
        do {
            try keychain.write(key, for: Self.keyAccount)
            keyField?.stringValue = ""
            statusLabel?.stringValue = savedStatus(key)
        } catch {
            log.error("Keychain write failed: \(String(describing: error), privacy: .public)")
            statusLabel?.stringValue = "Couldn't save to the Keychain."
        }
    }

    @objc private func removeKey(_ sender: NSButton) {
        do {
            try keychain.delete(Self.keyAccount)
            statusLabel?.stringValue = "Key removed."
        } catch {
            log.error("Keychain delete failed: \(String(describing: error), privacy: .public)")
            statusLabel?.stringValue = "Couldn't save to the Keychain."
        }
    }

    @objc private func openKeyPage(_ sender: NSButton) {
        guard let url = URL(string: "https://aistudio.google.com/apikey") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Settings

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, field === modelField else { return }
        settings.chatModel = field.stringValue
        field.stringValue = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? AppSettings.defaultChatModel : settings.chatModel
    }

    @objc private func walkingToggled(_ sender: NSButton) {
        settings.walkingEnabled = sender.state == .on
        freeWalkBox?.isEnabled = settings.walkingEnabled
        distanceSlider?.isEnabled = settings.walkingEnabled
        onWalkingChanged()
    }

    @objc private func freeWalkToggled(_ sender: NSButton) {
        settings.freeWalkEnabled = sender.state == .on
        if settings.freeWalkEnabled && !MenuBarScanner.isTrusted { MenuBarScanner.requestTrust() }
    }

    @objc private func loginToggled(_ sender: NSButton) {
        do {
            try LoginItem.setEnabled(sender.state == .on)
        } catch {
            log.error("Open at Login failed: \(error.localizedDescription, privacy: .public)")
            sender.state = LoginItem.isEnabled ? .on : .off
        }
    }

    @objc private func distanceChanged(_ sender: NSSlider) {
        settings.walkDistance = sender.doubleValue
    }
}
