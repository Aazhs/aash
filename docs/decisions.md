# Decisions

Newest at the bottom. Add a row whenever a card or a planning session settles something the docs
didn't. Don't rewrite old rows; add a new one that replaces them.

| Date | Decision | Why |
|---|---|---|
| 2026-10-17 | Chat uses the Gemini API (`gemini-3.5-flash-lite`); the Claude Code CLI comes later as an optional "Ask Claude" button. Apple's on-device model is dropped. | The user's call: on an 8 GB M1 that already lags, the on-device model would add memory pressure. Gemini's free tier needs no billing. |
| 2026-10-18 | Gemini through the Interactions API with `"store": false`. | It's the API Google's current docs are written for. With `store: false` no conversation is kept on Google's side between chats. |
| 2026-10-18 | Reminder phrases are parsed on the Mac (`NSDataDetector` plus rules); Gemini's JSON output is only a fallback. | Uses no quota, works instantly and offline. The research doc relied on the on-device model for this. |
| 2026-10-18 | Alerts come from an `EKAlarm` on the reminder; the app posts no notifications of its own. | One alert instead of two, it reaches the iPhone, and there's one fewer permission to ask for. |
| 2026-10-18 | AppKit for all UI, including the popover and settings. No SwiftUI. | Lowest memory, and one UI framework for agents to learn. The research doc suggested SwiftUI in the popover. |
| 2026-10-18 | Idle is a still frame that blinks every 3–6 s. | About 0.4 wake-ups a second, against 2 at a constant 2 fps. |
| 2026-10-18 | SwiftPM plus scripts, no Xcode; tests use Swift Testing. | Only the Command Line Tools are installed (36 GB free disk). They include Testing.framework but not XCTest. |
| 2026-10-18 | The scripts pass `-Xswiftc -plugin-path <toolchain>/usr/lib/swift/host/plugins/testing` to every `swift` command, and never use `--disable-xctest`. `test.sh` retries once on the macro error. | With the Command Line Tools, a test build after any plain `swift build` failed with "plugin for module 'TestingMacros' not found" (reproduced 3 times). With the flag, 7 of 7 build-edit-test cycles passed. `--disable-xctest` failed every time. |
| 2026-10-18 | Builds are signed with a self-signed "Aash Local" certificate when it exists, ad-hoc otherwise. | macOS ties Reminders and Accessibility permissions to the signature; ad-hoc signatures change on every build. |
| 2026-10-18 | Personal build: no App Store, no sandbox. | Free walking needs other apps' menu bar geometry. |
| 2026-10-18 | Four targets: `AashSprites`, `AashCore`, `AashAI` (libraries, independent of each other) and `Aash` (the app). | Pure logic stays testable, and two cards in different libraries can run in parallel. The plan had three; sprites got their own target for the T01 ∥ T03 pair. |
| 2026-10-18 | Walking is a stretch walk by default: the status item widens to the left and the buddy walks inside it. Free walking over the bar is opt-in and needs Accessibility. | Probe on macOS 27.0.1: other apps' status items aren't in `CGWindowListCopyWindowInfo` (they're hosted by `MenuBarAgent`), so the research doc's free-space method doesn't work. Our own item's frame is readable, and widening grows to the left with the right edge fixed. |
| 2026-10-18 | Free walk uses a sprite-sized panel, and the buddy is hidden while it passes behind other icons. | It never covers an icon or menu, and it takes clicks only on the buddy, with no click-through code. |
| 2026-10-18 | `walkArea` means where a walk may end; the way there is always allowed. | Free walk can then pass behind icons without the engine knowing about icons. |
| 2026-10-18 | The reminder wave goes through the engine (`reminderAt`), with no timer of its own. | Keeps the one-clock rule. |
| 2026-10-18 | New frames `blink`, `wave`, `waveHigh` and `sleep`; closed eyes `#c08f74`; dark-bar outline `#ede6f2` at 55%. | Chosen from previews at real menu bar size. An outline only around dark pixels filled the gap between the legs. |
| 2026-10-18 | T29: Retina pixelSize 4 (20x26 pt cell); no outline on dark or light bars. | Manual check: the outline looked like a white border. The outline pass and `SpriteStyle.outline` stay, unused. |
| 2026-10-18 | Opus runs only where judgment matters: `/plan-phase`, `/card`, the T04, T12 and T26 reviews, and T12's implementation. `Agent(model:opus)` asks first. | Pro plan limits. Everything else runs on Sonnet or Haiku. |
| 2026-10-18 | App name Aash, bundle id `me.aarshj.aash`. | From the folder name and the user's domain. Rename before T06 if wanted: the login item and permissions use the bundle id. |
| 2026-10-18 | No notch handling. `FreeWalkStage` passes no `blocked` ranges; `MenuBarLayout.blocked` stays in `AashCore`. | The only target Mac is a MacBook Air M1, which has no notch. |
| 2026-10-18 | Reduce Motion turns walking off (T27), without changing the stored setting. Blinks, waves and cheers stay. | Walking across the bar is the one large movement; the rest happens in place inside the icon. From the menu bar app guidelines (`macos-menubar-app` skill). |
| 2026-10-18 | From the `macos-menubar-app` skill we take `LSApplicationCategoryType` (utilities), system colours in the popover and settings, reopen opening the chat, and a crowded-bar check in T26. Its SwiftUI parts (`MenuBarExtra`, `Settings` scene, `@Observable` timers) and Carbon global hotkeys are not used. | AppKit only and one clock remain the rules. A global hotkey is a later idea, not v1. |
| 2026-10-18 | When a rescan mid-walk moves the free stretch's left edge past the target (wider menus came to the front), a buddy that is walking out and hasn't passed the new edge retargets to it instead of walking home (T30). Resting, or already past the edge, still walks home. | Reproduced: a free walk takes ~35 s, and an app switch a few seconds in turned the buddy back every time. The scan itself was fine, so keeping a stale plan or rescanning later would not help. |
