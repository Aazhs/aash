# T33 · Clipboard buttons, Chat menu item, reopen

Phase 3 · Target: Aash · Risk: low · Detail: full

## Goal

The chat popover gets three clipboard buttons (Summarise, Rewrite, Explain) that send the clipboard
text with the action's instruction. The right-click menu gets a "Chat" item, and opening Aash again
from Finder or Spotlight opens the popover.

## Read first

- `docs/ai.md#requests-the-app-makes`, `#the-buddys-voice`
- `Sources/Aash/ChatViewController.swift`, `ChatPopoverController.swift` (T17)
- `Sources/AashAI/ChatPrompts.swift` (T32)
- `Sources/Aash/AppMenu.swift`, `AppDelegate.swift`

## Files

- edit `Sources/Aash/ChatViewController.swift`: a button row
- edit `Sources/Aash/AppMenu.swift`: a "Chat" item
- edit `Sources/Aash/AppDelegate.swift`: pass the menu callback; handle reopen

## Interfaces

```swift
// ChatViewController.swift: add
/// Sends the clipboard text with this action's instruction, as one user message.
func runClipboardAction(_ action: ChatPrompts.ClipboardAction)

// AppMenu.swift: a new init parameter, placed before onWalkNow
onOpenChat: @escaping () -> Void

// AppDelegate.swift: add
func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
```

## Steps

1. `ChatViewController`: refactor `send(_:)` so that it calls a private
   `submit(_ text: String, display: String)`: `text` is what goes into history and to Gemini, `display`
   is what the transcript shows for the user's turn. For typed messages both are the typed text.
2. `runClipboardAction(_:)`: read `NSPasteboard.general.string(forType: .string)`. If it's nil or
   empty after trimming, append the notice "Nothing to work on: copy some text first." in the notice
   style and return. Otherwise `submit(ChatPrompts.clipboardMessage(action, text: clip), display:
   "\(action.title): \(String(clip.prefix(60)))…")` (drop the `…` when the clipboard has 60
   characters or fewer; replace newlines in the display text with spaces). Ignore while `streaming`.
3. In `loadView`, add a horizontal `NSStackView` row (spacing 6, `distribution = .fillEqually`) of
   three `.rounded` buttons titled from `ChatPrompts.ClipboardAction.allCases.map(\.title)`, between the
   scroll view and the input. Each button's action calls `runClipboardAction` for its case; store the
   case with `tag` (the index into `allCases`) and use one `@objc` method.
4. `AppMenu`: add `NSMenuItem(title: "Chat", action: #selector(openChat(_:)), keyEquivalent: "")`
   as the first item, followed by a separator. `openChat` calls `onOpenChat()`. Set `target = self`.
5. `AppDelegate`: pass `onOpenChat: { [weak self] in self?.chat?.show() }`. Because the menu closes
   before its action runs, the popover can open from the menu item. Add
   `applicationShouldHandleReopen` which calls `chat?.show()` and returns `false` (an accessory app
   otherwise shows nothing when launched a second time).

## Rules

- Same as T17: system colours only, no timers, nothing logged from user text.
- Don't change how `send(_:)` behaves for typed text.
- Keep `ChatViewController.swift` under about 300 lines; if it passes that, stop and report.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `grep -rn "print(" Sources/Aash` finds nothing

## Manual check

1. Run `./scripts/run.sh`. Copy a paragraph of text.
2. Ask: "Open the chat and click Summarise: does your turn show 'Summarise: <start of the text>…' and
   does a reply stream in? Clear the clipboard text (copy an image or nothing) and click Explain: is
   there a 'Nothing to work on' line? Right-click the buddy: is 'Chat' the first item and does it open
   the popover? Run `open build/Aash.app` while Aash is running: does the popover open?"
3. Needs a saved Gemini key for the reply parts; without one, expect the no-key line.

## Out of scope

- Reading images or files from the clipboard.
- New actions beyond the three in `docs/ai.md`.
- A global hotkey.

## Notes

- Clipboard text is cut to 20,000 characters inside `ChatPrompts.clipboardMessage` (T32), not here.
- The clipboard goes to Google on the free tier; the user was told in `docs/WORKFLOW.md#gemini-key`.
