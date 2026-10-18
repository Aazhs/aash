# T18 · Settings window

Phase 3 · Target: Aash · Risk: low · Detail: full

## Goal

A small AppKit settings window, opened from the right-click menu ("Settings…"): the Gemini API key
(kept in the Keychain), the chat model, walking on or off, walking on the whole bar, open at login,
and walk distance. It is built when opened and freed when closed.

## Read first

- `docs/patterns.md#appkit-layout`, `#settings`, `#keychain`, `#logging`
- `docs/architecture.md#settings-keys`
- `docs/ai.md#keychain`
- `Sources/Aash/AppSettings.swift`, `AppMenu.swift`, `AppDelegate.swift`, `LoginItem.swift`,
  `MenuBarScanner.swift` (only `isTrusted` and `requestTrust()`)
- `Sources/AashAI/KeychainStore.swift` (T16)

## Files

- create `Sources/Aash/SettingsWindowController.swift`
- edit `Sources/Aash/AppSettings.swift`: add `chatModel`
- edit `Sources/Aash/AppMenu.swift`: a "Settings…" item and its callback
- edit `Sources/Aash/AppDelegate.swift`: own and open the window

## Interfaces

```swift
// AppSettings.swift: add
/// The Gemini model used for chat. Default "gemini-3.5-flash-lite"; an empty saved value reads as the default.
var chatModel: String {
    get {
        let saved = defaults.string(forKey: "chatModel")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? AppSettings.defaultChatModel : saved
    }
    set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "chatModel") }
}
/// The model used when none is saved.
static let defaultChatModel = "gemini-3.5-flash-lite"

// AppMenu.swift: a new init parameter, placed after onWalkingChanged
onOpenSettings: @escaping () -> Void

// SettingsWindowController.swift
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    /// The Keychain account that holds the Gemini key (docs/ai.md#keychain).
    static let keyAccount = "gemini"
    init(settings: AppSettings, keychain: KeychainStore = KeychainStore(),
         reduceMotion: @escaping () -> Bool,
         onWalkingChanged: @escaping () -> Void,
         onClose: @escaping () -> Void)
    /// Builds the window if needed, activates the app and brings the window to the front.
    func show()
}
```

## Steps

1. `AppSettings.chatModel` and `defaultChatModel` exactly as above. Keep the file's style.
2. `AppMenu`: store `onOpenSettings`. Add `NSMenuItem(title: "Settings…", action: #selector(openSettings(_:)),
   keyEquivalent: ",")` between the "Open at Login" separator block and "About Aash": order becomes
   Walk now, Walking, Walk on the Whole Bar, separator, Open at Login, Settings…, separator, About,
   (alternate report), Quit. Set `target = self`. The `@objc` method calls `onOpenSettings()`.
3. `AppDelegate`: add `private var settingsWindow: SettingsWindowController?`. Add
   `private func openSettings()`: if `settingsWindow == nil`, create it with `settings`,
   `reduceMotion: { [weak self] in self?.systemEvents?.reduceMotion ?? false }`,
   `onWalkingChanged: { [weak self] in self?.sendWalking() }` and
   `onClose: { [weak self] in self?.settingsWindow = nil }`; then `settingsWindow?.show()`. Pass
   `onOpenSettings: { [weak self] in self?.openSettings() }` to `AppMenu`.
   (`AppDelegate` already guards `settings` being optional; use the local `settings` constant in
   `applicationDidFinishLaunching` and store the closure there.)
4. `SettingsWindowController`: build lazily in `show()`; keep `private var window: NSWindow?`.
   Layout: a vertical `NSStackView` (spacing 12, edge insets 20) in a titled, closable window,
   width 420 pt, title "Aash Settings", `isReleasedWhenClosed = false`, `delegate = self`,
   `center()`. Rows, top to bottom, built with `makeRow` from `docs/patterns.md#appkit-layout`:
   1. **Gemini key**: an `NSSecureTextField` (placeholder "Paste your key") with Save and Remove
      buttons.
      - Under it a small secondary-colour label (`.secondaryLabelColor`, `.smallSystemFont`) showing the
        status line.
      - Under that a link-style button "Get a free key at aistudio.google.com"
        (`bezelStyle = .inline`, `isBordered = false`, `contentTintColor = .linkColor`) that does
        `NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/apikey")…)` (build the URL with
        `guard let`).
      - At show time read `keychain.read(Self.keyAccount)`. If a key exists: status "Saved: •••• \(last4)"
        where `last4` is the last four characters (the whole key if shorter). If none: "No key saved."
        If reading throws: "Couldn't read the Keychain." and log the status at `.error`
        (category `Settings`, never the key).
      - **Save**: `trimmingCharacters(in: .whitespacesAndNewlines)`; empty → status "Paste a key first.".
        Otherwise `keychain.write`, clear the field, status "Saved: •••• \(last4)"; on error
        "Couldn't save to the Keychain."
      - **Remove**: `keychain.delete`; status "Key removed."; on error the same error line.
      - The field is never filled with the saved key.
   2. **Model**: `NSTextField` with `placeholderString = AppSettings.defaultChatModel`, showing
      `settings.chatModel`. On end editing (`controlTextDidEndEditing`) write `settings.chatModel` with its
      text; if the text is empty write "" and show the default again.
   3. **Walking** checkbox (`NSButton(checkboxWithTitle:target:action:)`): `settings.walkingEnabled`;
      on change set it and call `onWalkingChanged()`.
   4. **Walk on the whole bar** checkbox, indented: `settings.freeWalkEnabled`; on change set it, and when
      turned on and `!MenuBarScanner.isTrusted` call `MenuBarScanner.requestTrust()` (as `AppMenu` does).
      Disabled while walking is off.
   5. **Open at login** checkbox: `LoginItem.isEnabled`; on change `try LoginItem.setEnabled(sender.state
      == .on)`; on failure log at `.error`, and set the checkbox back to `LoginItem.isEnabled`.
   6. **Walk distance**: a label "Walk distance" and an `NSSlider(value:minValue:maxValue:target:action:)`
      24…240, `isContinuous = false`, value `settings.walkDistance`; on change set `settings.walkDistance`.
      Disabled while walking is off.
   7. When `reduceMotion()` is true: walking, whole-bar and distance controls are disabled and a small
      secondary label says "Walking is off while Reduce Motion is on." (Read once at `show()`.)
5. `show()`: build if `window == nil`; `NSApp.activate()`; `window.makeKeyAndOrderFront(nil)`. (An
   accessory app must activate first, or the window opens behind the frontmost app.)
6. `windowWillClose(_:)`: do `window?.delegate = nil`, then `window = nil`, then call `onClose()`.
   `AppDelegate` drops its reference to the controller in `onClose`, which frees the controller and
   its controls.
7. Update `docs/architecture.md#settings-keys` only if a key differs from the table (it shouldn't).

## Rules

- AppKit only; system colours and fonts only (`.labelColor`, `.secondaryLabelColor`, `.linkColor`),
  so light, dark and the accent colour work (`docs/decisions.md`, menubar skill row).
- Build the window on open, free it on close (`docs/performance.md#rules-that-keep-it-there`, rule 8).
- Never log or print the key. Logger category `Settings`; numbers `privacy: .public`.
- No timers. Everything is `@MainActor`. Keep the file under about 300 lines; if it grows past that,
  stop and report rather than splitting on your own.
- `isReleasedWhenClosed = false` (with ARC, `true` would over-release); the window is freed by dropping
  the reference.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `grep -rn "Timer(" Sources/Aash` still finds only `AnimationClock.swift`
- [ ] `grep -rn "print(" Sources/Aash` finds nothing
- [ ] No tests to add: the app target has none

## Manual check

1. Run `./scripts/run.sh`.
2. Ask: "Right-click the buddy → Settings…. Does a window open in front? Paste your real Gemini key
   and click Save: does it say 'Saved: •••• ' plus the last four characters, and does the field
   empty? Close and reopen: is the status still shown? Untick Walking: do the whole-bar and distance
   controls grey out, and does the right-click menu agree?"
3. Do not click Remove unless the user wants to.

## Out of scope

- Chat (T17). Testing the key against Gemini ("Test key" button).
- A global ⌘, shortcut: Aash has no main menu, so ⌘, only shows in the right-click menu.
- Changing the existing menu items' behaviour.

## Notes

- The Keychain item is service `me.aarshj.aash`, account `gemini` (`KeychainStore()` default service).
- The chat popover (T17) reads the key and model each time it opens, so a saved key works at once.
