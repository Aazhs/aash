import AppKit
import AashAI
import AashCore
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Chat")

/// The popover's content: a transcript, an optional Open Settings button and a text field.
@MainActor
final class ChatViewController: NSViewController {
    private let provider: any ChatProvider
    private let reminders: ReminderIntent
    private let hasKey: Bool
    private let openSettings: () -> Void
    private let onReply: () -> Void
    private let textView = NSTextView()
    private let settingsButton = NSButton(title: "Open Settings", target: nil, action: nil)
    private let undoButton = NSButton(title: "Undo", target: nil, action: nil)
    private let input = NSTextField()
    private var history: [ChatMessage] = []
    private var streaming = false
    private var streamTask: Task<Void, Never>?
    private var reply = ""
    private var reminderTask: Task<Void, Never>?
    private var lastAdded: (id: String, title: String)?

    /// `provider` answers messages; `hasKey` false shows the no-key line at once.
    init(provider: any ChatProvider, reminders: ReminderIntent, hasKey: Bool,
         openSettings: @escaping () -> Void,
         onReply: @escaping () -> Void) {
        self.provider = provider
        self.reminders = reminders
        self.hasKey = hasKey
        self.openSettings = openSettings
        self.onReply = onReply
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 420))

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.setContentHuggingPriority(.init(1), for: .vertical)

        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked(_:))
        settingsButton.isHidden = true

        undoButton.bezelStyle = .rounded
        undoButton.target = self
        undoButton.action = #selector(undoClicked(_:))
        undoButton.isHidden = true

        input.placeholderString = "Ask Aash…"
        input.target = self
        input.action = #selector(send(_:))
        input.bezelStyle = .roundedBezel

        let buttons = ChatPrompts.ClipboardAction.allCases.enumerated().map { index, action in
            let button = NSButton(title: action.title, target: self, action: #selector(clipboardClicked(_:)))
            button.bezelStyle = .rounded
            button.tag = index
            return button
        }
        let row = NSStackView(views: buttons)
        row.orientation = .horizontal
        row.spacing = 6
        row.distribution = .fillEqually

        let stack = NSStackView(views: [scroll, settingsButton, undoButton, row, input])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        ])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if !hasKey { showNotice(ChatError.noKey) }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(input)
    }

    /// Cancels any request in flight. Safe to call twice.
    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        reminderTask?.cancel()
        reminderTask = nil
        streaming = false
    }

    @objc private func settingsClicked(_ sender: Any?) {
        openSettings()
    }

    @objc private func send(_ sender: Any?) {
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !streaming else { return }
        input.stringValue = ""
        hideUndo()
        if !ReminderPhraseParser.isReminderRequest(text) {
            submit(text, display: text)
            return
        }
        appendText(text, color: .controlAccentColor, separate: true)
        streaming = true
        let intent = reminders
        reminderTask = Task { @MainActor [weak self] in
            let outcome = await intent.handle(text)
            guard !Task.isCancelled else { return }
            self?.finishReminder(outcome, text: text)
        }
    }

    private func finishReminder(_ outcome: ReminderIntent.Outcome, text: String) {
        streaming = false
        reminderTask = nil
        switch outcome {
        case .added(let id, let title, let due):
            appendText(ChatPrompts.reminderAdded(title: title, due: due, now: Date(), calendar: .current),
                       color: .labelColor, separate: true)
            lastAdded = (id, title)
            undoButton.isHidden = false
            onReply()
        case .notReminder:
            submit(text, display: nil)
        case .noAccess:
            appendText(ChatPrompts.remindersNoAccess, color: .secondaryLabelColor, separate: true)
        case .failed:
            appendText(ChatPrompts.reminderFailed, color: .secondaryLabelColor, separate: true)
        }
        textView.scrollToEndOfDocument(nil)
    }

    private func hideUndo() {
        undoButton.isHidden = true
        lastAdded = nil
    }

    @objc private func undoClicked(_ sender: Any?) {
        guard let added = lastAdded else { return }
        hideUndo()
        let line = reminders.undo(id: added.id)
            ? ChatPrompts.reminderRemoved(title: added.title) : ChatPrompts.reminderUndoFailed
        appendText(line, color: .secondaryLabelColor, separate: true)
        textView.scrollToEndOfDocument(nil)
    }

    /// Sends the clipboard text with this action's instruction, as one user message.
    func runClipboardAction(_ action: ChatPrompts.ClipboardAction) {
        guard !streaming else { return }
        hideUndo()
        let clip = NSPasteboard.general.string(forType: .string) ?? ""
        if clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendText("Nothing to work on: copy some text first.", color: .secondaryLabelColor, separate: true)
            textView.scrollToEndOfDocument(nil)
            return
        }
        let shown = String(clip.prefix(60)).replacingOccurrences(of: "\n", with: " ")
        let ellipsis = clip.count > 60 ? "…" : ""
        submit(ChatPrompts.clipboardMessage(action, text: clip), display: "\(action.title): \(shown)\(ellipsis)")
    }

    @objc private func clipboardClicked(_ sender: NSButton) {
        let actions = ChatPrompts.ClipboardAction.allCases
        guard actions.indices.contains(sender.tag) else { return }
        runClipboardAction(actions[sender.tag])
    }

    private func submit(_ text: String, display: String?) {
        history.append(ChatMessage(role: .user, text: text))
        history = Array(history.suffix(20))
        if let display { appendText(display, color: .controlAccentColor, separate: true) }
        streaming = true
        reply = ""
        let provider = self.provider
        let messages = history
        streamTask = Task { @MainActor [weak self] in
            do {
                for try await chunk in provider.stream(messages, system: ChatPrompts.system) {
                    self?.append(chunk)
                }
                self?.finishReply()
            } catch {
                self?.fail(error)
            }
        }
    }

    private func append(_ chunk: String) {
        // Each reply starts a new paragraph; later chunks continue it.
        appendText(chunk, color: .labelColor, separate: reply.isEmpty)
        reply += chunk
        textView.scrollToEndOfDocument(nil)
    }

    private func finishReply() {
        guard !Task.isCancelled else { return }
        if reply.isEmpty {
            fail(ChatError.badResponse("empty reply"))
            return
        }
        history.append(ChatMessage(role: .model, text: reply))
        streaming = false
        onReply()
    }

    private func fail(_ error: Error) {
        guard !Task.isCancelled else { return }
        streaming = false
        if history.last?.role == .user { history.removeLast() }
        let chatError = (error as? ChatError) ?? .badResponse("unexpected error")
        showNotice(chatError)
        switch chatError {
        case .server(let status, _):
            log.error("Chat failed: server \(status, privacy: .public)")
        case .noKey: log.error("Chat failed: noKey")
        case .badKey: log.error("Chat failed: badKey")
        case .quota: log.error("Chat failed: quota")
        case .offline: log.error("Chat failed: offline")
        case .timedOut: log.error("Chat failed: timedOut")
        case .badResponse: log.error("Chat failed: badResponse")
        }
    }

    private func showNotice(_ error: ChatError) {
        appendText(error.userMessage(), color: .secondaryLabelColor, separate: true)
        if error == .noKey { settingsButton.isHidden = false }
        textView.scrollToEndOfDocument(nil)
    }

    /// Appends one styled piece; `separate` puts a blank line before it unless the transcript is empty.
    private func appendText(_ text: String, color: NSColor, separate: Bool) {
        guard let storage = textView.textStorage else { return }
        let prefix = (separate && storage.length > 0) ? "\n\n" : ""
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color,
        ]
        storage.append(NSAttributedString(string: prefix + text, attributes: attributes))
    }
}
