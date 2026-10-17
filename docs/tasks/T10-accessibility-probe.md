# T10 · Accessibility probe

Phase 2 · Target: Aash · Risk: medium · Detail: full

## Goal

Find out, on this Mac, what the Accessibility API reveals about the menu bar on macOS 27: the
frontmost app's menus and the other status items. `MenuBarScanner` reads it, a hidden menu item
copies a report, and the findings go into `docs/menubar.md`. T11 and T12 depend on the answer.

## Read first

- `docs/menubar.md#free-walk` and `#what-macos-27-does`
- `tools/menubar-probe.swift`: the same Accessibility calls, as a script
- `Sources/Aash/AppMenu.swift`

## Files

- create `Sources/Aash/MenuBarScanner.swift`
- edit `Sources/Aash/AppMenu.swift`: a hidden "Copy Menu Bar Report" item

## Interfaces

```swift
// MenuBarScanner.swift
import AppKit
import ApplicationServices

/// One thing found on the menu bar, in AppKit screen coordinates (origin bottom-left).
struct MenuBarElement: Equatable {
    let owner: String
    let frame: CGRect
}

/// What an Accessibility scan of the menu bar found.
struct MenuBarScan: Equatable {
    var trusted: Bool
    /// The frontmost app's top-level menus, left to right.
    var appMenus: [MenuBarElement]
    /// Status items from each running app's "AXExtrasMenuBar" attribute.
    var extras: [MenuBarElement]
    /// Children of the MenuBarAgent process's elements, if it exposes any.
    var agentItems: [MenuBarElement]
}

/// Reads the menu bar through the Accessibility API. Needs the user's permission.
@MainActor
enum MenuBarScanner {
    /// Whether Aash has Accessibility permission.
    static var isTrusted: Bool { get }
    /// Shows the system prompt that sends the user to System Settings to allow Aash.
    static func requestTrust()
    /// Scans now. Returns an empty scan with `trusted == false` without permission.
    static func scan() -> MenuBarScan
    /// A plain-text report of a scan plus screen and status item geometry.
    static func report(_ scan: MenuBarScan, ownItem: CGRect?) -> String
}
```

## Steps

1. `isTrusted` = `AXIsProcessTrusted()`. `requestTrust()` calls
   `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)`.
2. Helpers, as in `tools/menubar-probe.swift`: read an element's `kAXPositionAttribute` and
   `kAXSizeAttribute`, and its `kAXChildrenAttribute`. Before reading any app, call
   `AXUIElementSetMessagingTimeout(element, 0.25)` so a hung app can't freeze the scan.
3. Accessibility frames use top-left screen coordinates. Convert each to AppKit's bottom-left:
   `y = primaryScreenHeight − axY − height`, where `primaryScreenHeight` is
   `NSScreen.screens.first?.frame.height`.
4. `scan()`:
   - `appMenus`: `NSWorkspace.shared.frontmostApplication` → `AXUIElementCreateApplication(pid)`
     → `kAXMenuBarAttribute` → children, with owner = the app's name.
   - `extras`: for every `NSWorkspace.shared.runningApplications` entry, `"AXExtrasMenuBar"` →
     children.
   - `agentItems`: running apps whose `bundleIdentifier` or `localizedName` contains
     `"MenuBarAgent"` → their `kAXChildrenAttribute`, then each child's children (two levels), keeping
     elements whose frame is inside the top 40 pt of the primary screen.
5. `report`: lines for: date, `ProcessInfo.processInfo.operatingSystemVersionString`, `trusted`,
   each screen's frame and `visibleFrame`, our item's frame, then each list sorted by `minX`
   (`owner · x … maxX`), and the counts.
6. `AppMenu`: right after "About Aash", add "Copy Menu Bar Report" with `isAlternate = true` and
   `keyEquivalentModifierMask = [.option]`, so it replaces About while ⌥ is held. If not trusted:
   call `requestTrust()` and copy the line "Accessibility isn't allowed yet." Otherwise copy
   `report(scan(), ownItem: <our status item window frame>)` with `NSPasteboard.general`. `AppMenu`
   needs the status item frame: add `ownItemFrame: @escaping () -> CGRect?` to its init and pass
   `{ [weak item] in item?.window?.frame }` from `AppDelegate`.

## Rules

- Scanning happens only when asked. No timers, no observers in this card.
- Never log or copy anything except geometry and app names.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] Without permission, the menu item doesn't crash and copies the "isn't allowed" line

## Manual check

1. Run `./scripts/run.sh`. If `scripts/build.sh` says `signed: ad-hoc`, tell the user to create the
   certificate first (`docs/WORKFLOW.md#signing`); otherwise the permission is lost on the next build.
2. Ask the user to: hold ⌥, right-click the buddy, choose Copy Menu Bar Report (the first time it
   opens the permission prompt); allow Aash under System Settings → Privacy & Security →
   Accessibility; then do it again and paste the report into the chat.
3. Replace the placeholder under `docs/menubar.md#accessibility-findings` with the report in a
   code block, then 2–3 lines of conclusion: which of `extras` and `agentItems` found the other
   status items, and whether `appMenus` gave sensible frames.
4. If neither list found other status items, add: "Free walk can't see other icons on this
   macOS; T11/T12 need re-planning", and tell the user to run
   `/card fix: free walk without status item positions`. Mark T11 and T12 `blocked` on the board
   with that reason.

## Out of scope

- Using the results to walk: T11 and T12.

## Notes

- `"AXExtrasMenuBar"` has no constant in the SDK; the string is the attribute name.
- Children come back as a `CFArray`; cast with `as? [AXUIElement]`.
