# T06 · Menu and open at login

Phase 1 · Target: Aash · Risk: low · Detail: full

## Goal

Right-clicking the buddy shows a proper menu: Open at Login (with a checkmark), About Aash and
Quit Aash. Open at Login uses `SMAppService`, so it shows up in System Settings like any other
app's login item.

## Read first

- `docs/patterns.md#status-item` (how the menu is shown on right click) and `#logging`
- `Sources/Aash/AppDelegate.swift` (T04, T05)

## Files

- create `Sources/Aash/LoginItem.swift`
- create `Sources/Aash/AppMenu.swift`
- edit `Sources/Aash/AppDelegate.swift`: replace the one-item Quit menu with `AppMenu`

## Interfaces

```swift
// LoginItem.swift
import ServiceManagement

/// Opening Aash at login, through SMAppService.
@MainActor
enum LoginItem {
    /// True when Aash is registered to open at login.
    static var isEnabled: Bool { get }
    /// Registers or unregisters Aash as a login item.
    static func setEnabled(_ enabled: Bool) throws
}

// AppMenu.swift
import AppKit

/// The menu shown when the buddy is right-clicked.
@MainActor
final class AppMenu: NSObject, NSMenuDelegate {
    let menu: NSMenu
    override init()
    func menuNeedsUpdate(_ menu: NSMenu)
}
```

## Steps

1. `LoginItem.isEnabled` = `SMAppService.mainApp.status == .enabled`. `setEnabled(true)` calls
   `SMAppService.mainApp.register()`; `setEnabled(false)` calls `unregister()`. Both can throw;
   let the error through.
2. `AppMenu.init`: build `menu` with, in order:
   1. "Open at Login": target `self`, action `toggleLogin(_:)`. Its `state` is set in `menuNeedsUpdate`.
   2. a separator
   3. "About Aash": target `self`, action `about(_:)`
   4. "Quit Aash": action `#selector(NSApplication.terminate(_:))`, key equivalent `"q"`, target nil
   Set `menu.delegate = self`.
3. `menuNeedsUpdate`: set the Open at Login item's `state` to `.on` when `LoginItem.isEnabled`,
   else `.off`.
4. `toggleLogin`: call `LoginItem.setEnabled(!LoginItem.isEnabled)`. On error, log it at `.error`
   (category `Settings`) with `error.localizedDescription`. Never show an alert.
5. `about`: `NSApp.activate()`, then `NSApp.orderFrontStandardAboutPanel(nil)`. An accessory app
   has to activate first or the panel opens behind other windows.
6. `AppDelegate`: create an `AppMenu`, keep a strong reference, and set `statusItem.menu = appMenu.menu`.

## Rules

- Mark `@objc private func` for menu actions; the selectors must exist.
- No `NSAlert`, no modal windows (`docs/architecture.md#errors`).

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] The menu has exactly the four entries above, in that order

## Manual check

1. Run `./scripts/install.sh`. Login items should point at the installed copy in
   `~/Applications`, not the build folder.
2. Ask: "Right-click the buddy: do you see Open at Login, About Aash and Quit Aash? Turn on Open at
   Login: does Aash appear under System Settings → General → Login Items & Extensions, and does the
   menu now show a checkmark? Turn it off again if you don't want it yet."

## Out of scope

- Walking items (Walk now, Walking): T08.
- Settings window, Chat: Phase 3.

## Notes

- `SMAppService` needs macOS 13 or later; the package targets 14, so no availability check is needed.
- If `register()` fails with "Operation not permitted", the app is probably running from a folder
  macOS doesn't allow for login items. Test with the installed copy.
