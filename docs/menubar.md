# Menu bar

The buddy's home is a 22 pt status item. By default it walks inside its own item, which widens
for the walk: that needs no permissions and can never cover anything. With Accessibility allowed,
a later phase lets it walk the free part of the bar instead.

## What macOS 27 does

Measured on this Mac (MacBook Air M1, 1440 × 900 pt, no notch, macOS 27.0.1) on 18 Oct 2026, with
`tools/menubar-probe.swift` and two throwaway probes:

| Fact | Value |
|---|---|
| Menu bar height | 30 pt (`screen.frame.maxY − visibleFrame.maxY`) |
| `NSStatusBar.system.thickness` | 22 pt |
| Status button bounds at `length = 22` | 22 × 22 pt |
| Status item window | `length + 16` pt wide (8 pt padding each side), 30 pt tall, level 25 |
| Our item's frame | readable: `item.button?.window?.frame`, e.g. x = 972, w = 38 |
| Widening the item | `length = 160` → the window grows to the **left**: x 1010 → 872, the right edge stays at 1048. Back to 22 restores it. |
| Other apps' status items in `CGWindowListCopyWindowInfo` | **Not listed.** Status items are hosted by a system process, `MenuBarAgent`; only full-width bar windows (1440 × 30) show up. Our own item isn't listed either. |
| Notch areas (`auxiliaryTopLeftArea`, `auxiliaryTopRightArea`) | `nil` on this Mac |
| Accessibility trust for the terminal | `AXIsProcessTrusted() == false`, so reading other apps' menus wasn't possible yet |

The research doc expected to find free space by listing status item windows. On macOS 27 that
doesn't work, which is why stretch walk is the default and free walk depends on Accessibility.

## Status item

- `NSStatusBar.system.statusItem(withLength: 22)`. The sprite is centred in the button: on Retina a
  15 × 19.5 pt cell (`sprites.md#size-on-screen`).
- Left click: the buddy reacts (`clicked`) and, from Phase 3, the chat opens. Right click: the menu
  (`patterns.md#status-item`).
- The item never shows a title or a system image; the sprite view is its only content.

## Stretch walk

The default, built by T08 and T09.

1. The engine asks for room (`needsWalkArea`).
2. `StretchStage.prepare()` sets `length = 22 + walkDistance` (default 120 pt), then reports
   `walkArea(-(walkDistance) ... 0)`.
3. Home is the rightmost 22 pt of the button. The sprite's x in button coordinates is
   `bounds.width − 22 + centringInset + offset`, rounded to device pixels. Because the item grows
   to the left, home stays exactly where it was on screen.
4. When the engine is home again (`needsWalkArea` false), `finish()` sets `length = 22`.

While the item is wide, other icons to its left slide over, then back. That's the price of needing
no permissions. Keep walks short and rare (every 5–15 min).

## Hidden bar, full screen, lock

When the status item can't be seen, the buddy shouldn't animate:

- `NSWindow.didChangeOcclusionStateNotification` on the status item's window: not `.visible` →
  `paused(true)`. T05 checks that this fires on macOS 27, and the card says what to do if it doesn't.
- Screen asleep (`NSWorkspace.screensDidSleepNotification`), screen locked (distributed
  notifications `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked`), and Low Power Mode
  also pause.
- 2026-10-18: on macOS 27 the occlusion notification did not fire for the status item during
  full screen (no `hidden` log line). Low Power and lock still pause; nothing else to do.

## Free walk

Opt-in, built by T10 to T12. Free walk is the research doc's original idea: the buddy steps out of its icon and walks along the
empty part of the bar. It needs two things macOS 27 doesn't hand out freely:

1. **Where other things are.** Without the window list, the only route is the Accessibility API,
   which needs the user's permission:
   - the frontmost app's menus: `AXUIElementCreateApplication(pid)` → `kAXMenuBarAttribute` →
     children → `kAXPositionAttribute` / `kAXSizeAttribute`;
   - status items: each app's `"AXExtrasMenuBar"` attribute, or the `MenuBarAgent` process's
     elements. T10 finds out which one works on macOS 27.
2. **A window to walk in.** A sprite-sized, borderless, non-activating `NSPanel` above the menu
   bar, on all Spaces, that moves along the free interval. It's only shown during a walk.
   Because it's only as big as the sprite, it takes clicks for the buddy and nothing else. T12
   settles the window level and collection behaviour.

Rules for free walk:

- It's off by default (`freeWalkEnabled`), and turning it on asks for Accessibility.
- No permission, or the scan returns nothing believable (no menus, overlapping frames, zero
  sizes): fall back to stretch walk for that walk, and log why.
- Re-scan when the frontmost app changes (`NSWorkspace.didActivateApplicationNotification`) and
  when screens change (`NSApplication.didChangeScreenParametersNotification`). Never scan on a timer.
- Avoid the notch: subtract `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` when they aren't nil.

## Probe tool

`swift tools/menubar-probe.swift` prints our own status item's frame and, when the terminal app has
Accessibility permission, the frontmost app's menus and every app's status items. Run it after a
macOS update to see what changed. It's a script, not part of the build.

## Accessibility findings

T10 fills this in with what the Accessibility scan returns on this Mac.
