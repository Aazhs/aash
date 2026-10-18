# T17 · Chat popover

Phase 3 · Target: Aash · Risk: medium · Detail: full

## Goal

Left-clicking the buddy opens a small AppKit popover with a transcript and a text field. Typing a
question and pressing Return streams Gemini's reply into the transcript. Closing the popover cancels
any request and frees every view. The buddy reacts: `chatOpened`, `chatClosed`, `replyArrived`.

## Read first

- `docs/ai.md#requests-the-app-makes`, `#errors-the-user-sees`
- `docs/patterns.md#appkit-layout`, `#streaming`, `#logging`, `#gotchas`
- `docs/performance.md#rules-that-keep-it-there` (rule 8: build on open, free on close)
- `docs/behaviour.md#events` (`chatOpened`, `chatClosed`, `replyArrived`)
- `Sources/Aash/AppDelegate.swift`, `StatusItemController.swift`, `BuddyController.swift`
- `Sources/AashAI/ChatProvider.swift`, `GeminiProvider.swift`, `ChatPrompts.swift`,
  `ChatError+Message.swift` (T31, T15, T32), `KeychainStore.swift` (T16)
- `Sources/Aash/SettingsWindowController.swift` (T18): only `keyAccount`

## Files

- create `Sources/Aash/ChatPopoverController.swift`
- create `Sources/Aash/ChatViewController.swift`
- edit `Sources/Aash/StatusItemController.swift`: expose the button
- edit `Sources/Aash/AppDelegate.swift`: own the popover; left click opens it

## Interfaces

```swift
// StatusItemController.swift: add
/// The status bar button, which the chat popover points at.
var button: NSStatusBarButton? { item.button }

// ChatPopoverController.swift
import AashAI
import AashCore
@MainActor
final class ChatPopoverController: NSObject, NSPopoverDelegate {
    /// `anchor` returns the view the popover points at. `openSettings` is what the "Open Settings"
    /// button does. `onEvent` receives `.chatOpened`, `.chatClosed` and `.replyArrived`.
    init(anchor: @escaping () -> NSView?, settings: AppSettings,
         keychain: KeychainStore = KeychainStore(),
         openSettings: @escaping () -> Void,
         onEvent: @escaping (BuddyEvent) -> Void)
    /// True while the popover is on screen.
    var isShown: Bool { get }
    /// Opens the popover, or closes it if it is open.
    func toggle()
    /// Opens the popover. Does nothing if it is already open.
    func show()
    /// Closes the popover.
    func close()
}

// ChatViewController.swift
@MainActor
final class ChatViewController: NSViewController {
    /// `provider` answers messages; `hasKey` false shows the no-key line at once.
    init(provider: any ChatProvider, hasKey: Bool,
         openSettings: @escaping () -> Void,
         onReply: @escaping () -> Void)
    /// Cancels any request in flight. Safe to call twice.
    func cancel()
}
```

## Steps

1. `StatusItemController.button` as above.
2. `ChatPopoverController.show()`:
   1. `guard popover == nil, let anchor = anchor() else { return }`.
   2. `let key = (try? keychain.read(SettingsWindowController.keyAccount)) ?? nil`, treated as missing
      when nil or empty.
   3. `GeminiProvider(apiKey: key, model: settings.chatModel)` → `ChatViewController(provider:hasKey:…)`.
      `openSettings` closes the popover, then calls the stored `openSettings`. `onReply` calls
      `onEvent(.replyArrived)`.
   4. `NSPopover()`: `contentSize = NSSize(width: 340, height: 420)`, `behavior = .transient`,
      `animates = false` (no animation work), `delegate = self`, `contentViewController = viewController`.
   5. `NSApp.activate()` then `popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)`
      (an accessory app must activate for the text field to take keys).
   6. `onEvent(.chatOpened)`. Keep strong refs `popover` and `viewController`.
3. `popoverDidClose(_:)` (also runs when the popover is dismissed by clicking elsewhere):
   `viewController?.cancel()`, `popover?.contentViewController = nil`, `popover = nil`,
   `viewController = nil`, then `onEvent(.chatClosed)`. `close()` calls `popover?.performClose(nil)`;
   `toggle()` is `isShown ? close() : show()`. `isShown` is `popover?.isShown ?? false`.
4. `ChatViewController.loadView()`: a plain `NSView` of 340 × 420 holding a vertical `NSStackView`
   (spacing 8, `edgeInsets` 12) pinned to all four edges (four constraints are the only hand-written ones),
   with, in order:
   1. A scroll view containing a manually built `NSTextView`: `isEditable = false`, `isSelectable = true`,
      `drawsBackground = false`, `textContainerInset = NSSize(width: 4, height: 6)`,
      `isVerticallyResizable = true`, `autoresizingMask = [.width]`,
      `textContainer?.widthTracksTextView = true`; scroll view `hasVerticalScroller = true`,
      `drawsBackground = false`, `borderType = .noBorder`. Give the scroll view a low content-hugging
      priority so it takes the free height.
   2. An "Open Settings" `NSButton` (title "Open Settings", `bezelStyle = .rounded`), `isHidden = true`
      until the no-key line is shown. Its action calls `openSettings`.
   3. An `NSTextField` input: `placeholderString = "Ask Aash…"`, `target = self`,
      `action = #selector(send(_:))` (Return sends), `bezelStyle = .roundedBezel`.
5. Text styling: base font `NSFont.systemFont(ofSize: 13)`. Your messages are drawn in
   `NSColor.controlAccentColor`, Aash's replies in `NSColor.labelColor`, notices and errors in
   `NSColor.secondaryLabelColor`. Build each piece as an `NSAttributedString` with the paragraph's
   font and `.foregroundColor`, and append it to `textView.textStorage`. Separate turns with a blank
   line (`"\n\n"`). No hard-coded colour values anywhere.
6. State: `private var history: [ChatMessage] = []`, `private var streaming = false`,
   `private var streamTask: Task<Void, Never>?`, `private var reply = ""`.
7. `send(_:)`:
   1. `let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)`; ignore if empty or
      `streaming`. Clear the field.
   2. `history.append(ChatMessage(role: .user, text: text))`, keeping only the last 20 messages
      (`history = Array(history.suffix(20))`). Append the user's text to the transcript.
   3. `streaming = true`, `reply = ""`. Then, per `docs/patterns.md#streaming`:
      ```swift
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
      ```
   4. `append(_ chunk:)`: `reply += chunk`, append the chunk to the transcript in the reply style,
      `textView.scrollToEndOfDocument(nil)`.
   5. `finishReply()`: `guard !Task.isCancelled else { return }` (a cancelled stream ends quietly, and
      must not cheer). If `reply` is empty → `fail(ChatError.badResponse("empty reply"))`. Otherwise
      `history.append(ChatMessage(role: .model, text: reply))`, `streaming = false`, `onReply()`.
   6. `fail(_ error:)`: `guard !Task.isCancelled`. `streaming = false`. Remove the last history message
      if it is the unanswered user message. Convert with `(error as? ChatError) ?? .badResponse(…)`,
      append `error.userMessage()` in the notice style; if it is `.noKey`, un-hide the Open Settings
      button. Log with `Logger(category: "Chat")`: only the case name and, for `.server`, the status
      (`privacy: .public`). Never the text or the message.
8. If `hasKey == false`, `viewDidLoad` appends `ChatError.noKey.userMessage()` in the notice style,
   un-hides the button, and `send` still works (the provider will throw `.noKey` without a request).
9. `viewDidAppear()`: `view.window?.makeFirstResponder(input)`.
10. `cancel()`: `streamTask?.cancel()`, `streamTask = nil`, `streaming = false`.
11. `AppDelegate`: add `private var chat: ChatPopoverController?`. In `applicationDidFinishLaunching`,
    after `controller.start(…)`, create it:
    `ChatPopoverController(anchor: { [weak item] in item?.button }, settings: settings,
    openSettings: { [weak self] in self?.openSettings() },
    onEvent: { [weak controller] in controller?.handle($0) })`.
    Add `private func buddyClicked()` = `buddy?.handle(.clicked); chat?.toggle()`. Set
    `item.onLeftClick = { [weak self] in self?.buddyClicked() }` **after** `controller.start` (it sets
    the same property) and `stage.onClick = { [weak self] in self?.buddyClicked() }`. Do not keep a
    second reference to the popover anywhere else.

## Rules

- Build the popover and its views when it opens, release them when it closes
  (`docs/performance.md`, rule 8). After `popoverDidClose`, no property of the controller may still
  reference the popover or the view controller.
- Cancel the stream task on close. The task captures `self` weakly.
- No timers, no `DispatchQueue`, no `asyncAfter` (CLAUDE.md rule 5). No SwiftUI.
- System colours and fonts only, so light, dark and the accent colour all work.
- Never log keys, prompts or replies (`docs/patterns.md#logging`).
- `NSApp.activate()` before showing, as in `AppMenu.about`.
- Keep each file under about 300 lines. If `ChatViewController` is heading past that, stop and report.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `grep -rn "Timer(" Sources/Aash` finds only `AnimationClock.swift`
- [ ] `grep -rn "print(" Sources/Aash` finds nothing
- [ ] No tests to add: the app target has none. The wording is tested by T32, the client by T15.

## Manual check

1. Run `./scripts/run.sh`. (If no key is saved yet, the first part still applies.)
2. Ask: "Left-click the buddy. Does a small popover open under it with a text field focused? With no
   key saved it should say 'Add your free Gemini key in Settings to chat.' and show an Open Settings
   button that opens Settings. With a key: type a question and press Return — does the reply stream
   in, and does the buddy throw its arms up when it finishes? Click the buddy again mid-reply: does
   the popover close and the reply stop? Does a second question remember the first?"
3. If the user has no key yet, skip the second half and say so in the report; T19 needs a key.

## Out of scope

- Clipboard buttons, the "Chat" menu item, and reopen handling: T33.
- Markdown rendering, copy buttons, history on disk, a Stop button.
- Reminders in chat: T22.

## Notes

- With `behavior = .transient`, clicking the status button while the popover is open dismisses it
  first; the same click may then reopen it. If that flickers, report it; don't add timers.
- If memory doesn't drop after closing, look for a retained `ChatViewController` or stream task. T19
  measures it.
- If the text view doesn't scroll, check `isVerticallyResizable` and `widthTracksTextView`.
