# T17 · Chat popover

Phase 3 · Target: Aash · Risk: medium · Detail: outline

## Goal

Left-clicking the buddy opens a small AppKit popover: a transcript, a text field, and three
clipboard buttons (Summarise, Rewrite, Explain). Replies stream in from Gemini. Closing the popover
cancels any request and frees the views. The buddy reacts: `chatOpened`, `chatClosed`,
`replyArrived`.

## Read first

- `docs/ai.md#requests-the-app-makes`, `#errors-the-user-sees`, `#the-buddys-voice`
- `docs/patterns.md#appkit-layout`, `#streaming`
- `docs/performance.md`, rule 8 (build on open, free on close)

## Files (expected)

- create `Sources/Aash/ChatPopoverController.swift` (owns the `NSPopover`, built per open)
- create `Sources/Aash/ChatViewController.swift` (transcript `NSTextView`, input `NSTextField`, buttons)
- edit `Sources/Aash/AppDelegate.swift` (left click → toggle the popover; add Chat to the menu)

## Sketch

- Popover about 340 × 420 pt, `behavior = .transient`, shown relative to the status button.
- Enter sends; the history is this popover session only; stream chunks append to the text view.
- No key → the `noKey` line with a button that opens Settings (T18; until then, a disabled button).
- Uses `GeminiProvider(apiKey: KeychainStore().read("gemini"))`.

## Done when (to be detailed by /plan-phase 3)

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Manual: ask a question → the reply streams; close mid-reply → it stops; the clipboard buttons
  work; the buddy cheers when a reply finishes

## Notes

- Measure memory before and after (T19 does it properly). If closing doesn't free memory, look for a
  retained view controller or stream task.
