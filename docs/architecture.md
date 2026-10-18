# Architecture

One rule shapes everything: the behaviour engine is a pure value type that turns events into an
output (a pose, an offset and when the clock should fire next). Everything else either feeds it
events or draws its output. That keeps the logic testable without a screen, and it means one clock
decides when the CPU wakes.

## Targets

| Target | Kind | May import | Holds |
|---|---|---|---|
| `AashSprites` | library | Foundation, CoreGraphics | Pixel grids, palette, sprite sheet rendering |
| `AashCore` | library | Foundation, os | Behaviour engine, clock schedule, free-space maths, reminder phrase parsing |
| `AashAI` | library | Foundation, Security, os | Chat messages, `ChatProvider`, Gemini client, stream parser, Keychain store, Claude Code provider |
| `Aash` | executable | everything above + AppKit, QuartzCore, EventKit, ServiceManagement, ApplicationServices | The app: status item, views, clock, system events, popover, settings, reminders |

- The three libraries don't depend on each other. Only `Aash` depends on them. That's what lets two
  cards in different libraries run in parallel.
- Tests exist for the libraries only (`Tests/<Library>Tests`). App code stays thin, so most logic
  lives where it can be tested.
- Shared test data lives in `Tests/Fixtures/`, outside any target (see `patterns.md#fixtures`).

## Data flow

```
 SystemEvents ──paused(Bool)──┐
 StatusItemController ─clicked─┤
 ChatPopoverController ─chat───┤        ┌─────────────────────────┐
 ReminderScheduler ─reminderAt─┼──────> │ BuddyController         │
 WalkStage ─walkArea(range)────┤        │  engine.handle(event)   │
 AnimationClock ─tick──────────┘        └───────────┬─────────────┘
                                                    │ BuddyOutput
                     ┌──────────────────────────────┼──────────────────────┐
                     ▼                              ▼                      ▼
        SpriteLayerView.show(pose,         WalkStage.prepare/place/   AnimationClock
        facingLeft, offset)                finish (widen the item,    .apply(schedule)
                                           or move the walk window)
```

- `BuddyController` is the only object that calls the engine. Everything reports events to it.
- The engine never reads the clock: every call passes `now`. Tests use fixed dates.
- `AnimationClock` holds the app's only repeating timer. Between events the engine asks for
  `.stopped`, `.once(at:)` or `.every(seconds:)`.

## Key types

The cards give the exact signatures; this is the map.

| Type | Target | File | Card | Job |
|---|---|---|---|---|
| `RGBA`, `SpriteFrame`, `SpriteArt` | AashSprites | `RGBA.swift`, `SpriteFrame.swift`, `SpriteArt.swift` | T01 | Grids and palette, ported from the website |
| `SpriteStyle`, `SpriteSheet`, `SpriteRenderer` | AashSprites | `SpriteSheet.swift`, `SpriteRenderer.swift` | T02 | One sheet image for all frames, plus each frame's `contentsRect` |
| `ClockSchedule` | AashCore | `ClockSchedule.swift` | T03 | `.stopped`, `.once(at:)`, `.every(seconds:)` |
| `Pose`, `BuddyEvent`, `BuddyOutput` | AashCore | `BuddyTypes.swift` | T03 | Engine inputs and outputs |
| `BehaviourConfig`, `BehaviourEngine` | AashCore | `BehaviourConfig.swift`, `BehaviourEngine.swift` | T03 | The state machine in [behaviour.md](behaviour.md) |
| `SplitMix64` | AashCore | `SplitMix64.swift` | T03 | Seeded random numbers, so tests are repeatable |
| `AnimationClock` | Aash | `AnimationClock.swift` | T04 | The one timer |
| `SpriteLayerView` | Aash | `SpriteLayerView.swift` | T04 | A layer-backed view that shows one frame of the sheet |
| `StatusItemController` | Aash | `StatusItemController.swift` | T04 | The `NSStatusItem`, clicks, width |
| `BuddyController` | Aash | `BuddyController.swift` | T04 | Owns the engine, clock and views; routes events |
| `SystemEvents` | Aash | `SystemEvents.swift` | T05 | Screen sleep, lock, Low Power, occlusion → `paused` |
| `AppMenu`, `LoginItem` | Aash | `AppMenu.swift`, `LoginItem.swift` | T06 | Right-click menu, open at login |
| `AppSettings` | Aash | `AppSettings.swift` | T08 | `UserDefaults`-backed settings |
| `WalkStage`, `StretchStage` | Aash | `WalkStage.swift`, `StretchStage.swift` | T08 | Where a walk happens: inside the widened status item |
| `MenuBarScanner` | Aash | `MenuBarScanner.swift` | T10 | Accessibility read of menus and status items |
| `FreeSpace` | AashCore | `FreeSpace.swift` | T11 | Pure maths: free intervals on the bar |
| `FreeWalkStage`, `WalkWindow` | Aash | `FreeWalkStage.swift`, `WalkWindow.swift` | T12 | Walking over the real free space |
| `ChatMessage`, `ChatProvider`, `ChatError` | AashAI | `ChatMessage.swift`, `ChatProvider.swift` | T31 | Provider-neutral chat |
| `ServerSentEventParser` | AashAI | `ServerSentEvents.swift` | T31 | SSE lines → events |
| `ChatPrompts`, `ChatError.userMessage` | AashAI | `ChatPrompts.swift`, `ChatError+Message.swift` | T32 | The buddy's voice, clipboard actions, error lines |
| `GeminiProvider`, `GeminiWire` | AashAI | `GeminiProvider.swift`, `GeminiWire.swift` | T15 | Gemini Interactions API, streaming |
| `KeychainStore` | AashAI | `KeychainStore.swift` | T16 | API keys |
| `ChatPopoverController`, `ChatViewController` | Aash | `ChatPopoverController.swift`, `ChatViewController.swift` | T17, T33 | The popover UI |
| `SettingsWindowController` | Aash | `SettingsWindowController.swift` | T18 | The settings window |
| `DateMatch`, `ReminderDateDetector` | AashCore | `DateMatch.swift`, `ReminderDateDetector.swift` | T20 | The date phrase in a message, independent of today's date |
| `ParsedReminder`, `ReminderPhraseParser` | AashCore | `ReminderPhraseParser.swift` | T35 | "remind me to X at 6" → title + date |
| `ReminderFallback`, `ReminderSuggestion` | AashAI | `ReminderFallback.swift` | T36 | The Gemini fallback request and its reply |
| `RemindersService` | Aash | `RemindersService.swift` | T21 | EventKit access |
| `ReminderIntent` | Aash | `ReminderIntent.swift` | T22 | Chat message → parser or Gemini → Reminders, and Undo |
| `ReminderScheduler` | Aash | `ReminderScheduler.swift` | T23 | Finds the next due reminder and sends `reminderAt`; no timer of its own |
| `ClaudeCodeProvider` | AashAI | `ClaudeCodeProvider.swift` | T37 | `claude -p` as a chat provider; T24 adds the Ask Claude button |

The placeholder files from Phase 0 (`AashSprites.swift`, `AashAI.swift` and their tests) are
deleted by the first card that adds real code to that target. `AashCore.version` stays: the
status item tooltip shows it.

## Threading

- Everything in `Sources/Aash` is `@MainActor`, including every controller and view.
- Library types are structs or enums, `Sendable`, with no shared mutable state.
- Network calls are `async` and run off the main actor inside `AashAI`. Results come back to the
  main actor through `for try await` in an `@MainActor` task.
- EventKit calls happen in `RemindersService`. Asking for access and fetching are `async`; saving or
  removing one reminder is a short synchronous call on the main actor (`decisions.md`, 19 Oct).
- Notification observers use `queue: .main` plus `MainActor.assumeIsolated` (`patterns.md#observers`).

## Settings keys

`AppSettings` owns these `UserDefaults` keys. Add new ones here when a card adds them.

| Key | Type | Default | Card |
|---|---|---|---|
| `walkingEnabled` | Bool | true | T08 |
| `walkDistance` | Double (pt) | 120 | T08 |
| `freeWalkEnabled` | Bool | false | T12 |
| `chatModel` | String | `gemini-3.5-flash-lite` | T18 |

Open at login isn't stored: `SMAppService.mainApp.status` is the truth (T06).

The Gemini API key is never in `UserDefaults`: it's in the Keychain (service `me.aarshj.aash`,
account `gemini`).

## Logging

Use `os.Logger` with subsystem `me.aarshj.aash` and one category per file area: `Status`,
`Behaviour`, `Walk`, `System`, `Chat`, `Gemini`, `Reminders`, `Settings`. Use `.debug` for
per-event detail and `.error` for failures. Never log a key or chat content. To read the logs:
`log stream --predicate 'subsystem == "me.aarshj.aash"' --level debug`.

## Errors

- Library code throws typed errors (`ChatError`, `KeychainStore.Error`).
- The app turns errors into a short, friendly line in the popover or menu, never a modal alert.
- A missing permission isn't an error: the feature switches off and says how to turn it on.
