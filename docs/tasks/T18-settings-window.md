# T18 · Settings window

Phase 3 · Target: Aash · Risk: low · Detail: outline

## Goal

A small AppKit settings window, opened from the menu ("Settings…", ⌘,): Gemini API key (stored in
the Keychain), model, walking on or off, walk on the whole bar, open at login, walk distance.

## Read first

- `docs/patterns.md#appkit-layout`, `#settings`, `#keychain`
- `docs/architecture.md#settings-keys`
- `docs/ai.md#keychain`

## Files (expected)

- create `Sources/Aash/SettingsWindowController.swift`
- edit `Sources/Aash/AppSettings.swift` (`chatModel`, default `gemini-3.5-flash-lite`)
- edit `Sources/Aash/AppMenu.swift` (Settings… item)
- edit `docs/architecture.md#settings-keys` if keys change

## Sketch

- `NSSecureTextField` for the key with Save and Remove buttons and a short status line ("Saved").
  The key is never shown back in full: once saved, show "•••• last 4 characters".
- A link-style button: "Get a free key at aistudio.google.com".
- Built when opened, released when closed (`isReleasedWhenClosed` plus dropping the reference).
- Aash is an accessory app, so call `NSApp.activate()` before `makeKeyAndOrderFront`, or the
  window opens behind the frontmost app. ⌘, works only while the window or popover is key.
- System colours only, as in T17. The walking toggles follow T27 (disabled while Reduce Motion is on).

## Done when (to be detailed by /plan-phase 3)

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Manual: save a key → chat works without restarting; toggles take effect at once
