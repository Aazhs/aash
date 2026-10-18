# T24 · Ask Claude

Phase 5 · Target: Aash · Risk: medium · Detail: full

## Goal

When "Ask Claude in chat" is on in Settings and `claude` is installed, the chat shows an
**Ask Claude** button next to the text field. It sends the typed question to Claude Code through
`ClaudeCodeProvider` (T37) and streams the answer into the same transcript. Closing the popover
kills the process. With the setting off (the default) or no `claude` on disk, nothing changes.

## Read first

- `docs/ai.md#claude-code-ask-claude-phase-5`
- `Sources/AashAI/ClaudeCodeProvider.swift` (T37): `candidates`, `locate`, `Failure`
- `Sources/Aash/ChatViewController.swift`, `Sources/Aash/ChatPopoverController.swift`
- `docs/patterns.md#settings`

## Files

- edit `Sources/Aash/AppSettings.swift`: `askClaudeEnabled`
- edit `Sources/Aash/SettingsWindowController.swift`: one checkbox
- edit `Sources/Aash/ChatPopoverController.swift`: build the Claude provider in `show()`
- edit `Sources/Aash/ChatViewController.swift`: the button, its action, and the Claude failure line
- edit `docs/architecture.md`: add the key to `#settings-keys`

## Interfaces

```swift
// AppSettings.swift
/// Whether the chat shows the Ask Claude button (needs Claude Code installed). Default false.
var askClaudeEnabled: Bool {
    get { defaults.object(forKey: "askClaudeEnabled") as? Bool ?? false }
    set { defaults.set(newValue, forKey: "askClaudeEnabled") }
}

// ChatViewController.swift: the init gains `claude`, right after `provider`
/// `claude` nil hides the Ask Claude button.
init(provider: any ChatProvider, claude: (any ChatProvider)?, reminders: ReminderIntent, hasKey: Bool,
     openSettings: @escaping () -> Void,
     onReply: @escaping () -> Void)

// ChatViewController.swift: submit gains an optional provider; nil means Gemini
private func submit(_ text: String, display: String?, to other: (any ChatProvider)? = nil)
```

## Steps

1. **AppSettings:** add `askClaudeEnabled` exactly as above.
2. **Settings window:** in `makeWindow()`, right after the `Model` row, add
   `NSButton(checkboxWithTitle: "Ask Claude in chat (uses your Claude plan)", target: self, action: #selector(askClaudeToggled(_:)))`.
   Its state comes from `settings.askClaudeEnabled`. Find `claude` with
   `ClaudeCodeProvider.locate(in: ClaudeCodeProvider.candidates(home: FileManager.default.homeDirectoryForCurrentUser))`.
   If that's nil, disable the checkbox and add `smallLabel("Install Claude Code to use this.")`
   below it. `askClaudeToggled` sets `settings.askClaudeEnabled = sender.state == .on`.
   `SettingsWindowController.swift` needs `import AashAI` if it doesn't have it yet.
3. **Popover:** in `ChatPopoverController.show()`, before making the view controller:
   ```swift
   let claude = settings.askClaudeEnabled
       ? ClaudeCodeProvider.locate(in: ClaudeCodeProvider.candidates(home: FileManager.default.homeDirectoryForCurrentUser))
           .map { ClaudeCodeProvider(executable: $0) }
       : nil
   ```
   Pass `claude: claude` to `ChatViewController`. The check runs on each open: three `stat`
   calls, and nothing at launch.
4. **View controller, layout:** store `private let claude: (any ChatProvider)?` and
   `private let askButton = NSButton(title: ChatPrompts.askClaudeTitle, target: nil, action: nil)`.
   In `loadView()`, set `askButton.bezelStyle = .rounded`, its target and action
   (`askClaudeClicked(_:)`), and `askButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)`.
   Put `input` in a horizontal `NSStackView` with spacing 6: `[input, askButton]` when `claude`
   isn't nil, `[input]` otherwise. That row takes `input`'s place in the main stack.
5. **View controller, action:**
   ```swift
   @objc private func askClaudeClicked(_ sender: Any?) {
       guard let claude, !streaming else { return }
       let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
       guard !text.isEmpty else {
           appendText(ChatPrompts.askClaudeEmpty, color: .secondaryLabelColor, separate: true)
           textView.scrollToEndOfDocument(nil)
           return
       }
       input.stringValue = ""
       hideUndo()
       submit(text, display: "\(ChatPrompts.askClaudeTitle): \(text)", to: claude)
   }
   ```
   It never goes through the reminder parser. Return in the text field still sends to Gemini as
   before.
6. **submit:** add the `to other:` parameter and use `let provider = other ?? self.provider`.
   Nothing else in `submit` changes. Claude's reply joins `history` like any reply, so a
   following Gemini message sees it.
7. **fail:** right after `if history.last?.role == .user { history.removeLast() }`, insert:
   ```swift
   if let failure = error as? ClaudeCodeProvider.Failure {
       appendText(ChatPrompts.claudeFailed, color: .secondaryLabelColor, separate: true)
       textView.scrollToEndOfDocument(nil)
       log.error("Ask Claude failed: \(String(describing: failure), privacy: .public)")
       return
   }
   ```
8. **Docs:** add the row `| askClaudeEnabled | Bool | false | T24 |` to
   `docs/architecture.md#settings-keys`.

## Rules

- `cancel()` already cancels `streamTask`, and that is what kills `claude` (T37). Don't add
  another path, and don't keep a reference to the provider outside the view controller.
- Nothing runs at launch, and nothing polls (`docs/performance.md`, rules 7 and 9).
- `ChatViewController.swift` stays at about 300 lines (271 now). Don't split it.
- Never log the question or the reply.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] No new tests: the app target has none
- [ ] `grep -rn "ClaudeCodeProvider(" Sources/Aash` finds one line, in `ChatPopoverController.swift`

## Manual check

The orchestrator runs `./scripts/run.sh`, then asks the user to do the steps below. It asks:
"Did Ask Claude answer, and did each step do what it says?" This uses three small Haiku calls on
your Claude plan.

1. Settings → tick "Ask Claude in chat". Close Settings and open the chat: an **Ask Claude**
   button sits right of the text field.
2. Type `what's a good name for a pixel cat?` and click **Ask Claude**. The line
   `Ask Claude: what's…` appears, a short reply streams in within about 3 s, and the buddy cheers.
3. Press Return on an empty field, then click **Ask Claude** with it empty: the second shows
   "Type a question first, then click Ask Claude."
4. Type `explain how a CPU cache works in about 400 words`, click **Ask Claude**, and close the
   popover while it is still writing. The orchestrator then runs `pgrep -fl "claude -p"`, which
   must print nothing.
5. Type `hello` and press Return: a normal Gemini reply.
6. Settings → untick it, then reopen the chat: no button.

## Out of scope

- Sending the conversation to Claude: only the typed question goes (T37).
- Choosing Claude's model in Settings. It is Haiku.
- A keyboard shortcut for Ask Claude, or Claude for the clipboard buttons or reminders.
- Changing the `ChatError` wording for Gemini.

## Notes

- `claude` is a separate process: about 160 MB peak for about 3 s, which isn't counted in
  Aash's footprint. If Aash quits while it runs, it finishes its short reply and exits by itself.
- If step 2 works in Terminal but not from the app, read the `Chat` log for the `Failure`. A GUI
  app's `PATH` is short, but `claude` is a native binary started by its full path.
