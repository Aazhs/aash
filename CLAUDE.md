# Aash: a pixel buddy for the macOS menu bar

Aash is a small native macOS app. A pixel character lives in the menu bar, goes for short walks,
chats through the Gemini API and waves when an Apple Reminders task is due. It has to stay tiny:
see the budget below. Start at docs/README.md for everything else.

## How work happens here

- Work arrives as task cards in `docs/tasks/`. Do one card at a time, and only what it says.
- `docs/tasks/BOARD.md` is the status board. The `/next` skill runs the pipeline; `docs/WORKFLOW.md` explains it.
- If a card is wrong, unclear or impossible, stop and say so in your report. Don't invent a different design.

## Commands

Never run `swift`, `xcodebuild` or Xcode directly. The scripts add low CPU priority, a toolchain
fix and short output.

| Command | What it does |
|---|---|
| `./scripts/check.sh` | Build and run every test. A card is done only when this prints `CHECK PASS` |
| `./scripts/check.sh --target AashCore` | Compile one library only, for parallel cards. Runs no tests |
| `./scripts/test.sh --filter Name` | Run only the tests whose name matches |
| `./scripts/run.sh` | Build and launch the app (quits the old one first) |
| `./scripts/measure.sh 60 idle` | CPU, wake-ups and memory against the budget; adds a row to `docs/perf-log.md` |
| `./scripts/install.sh` | Release build into `~/Applications` |

Full logs are in `build/logs/`. Read them only when the short output isn't enough.

## Hard rules

1. **Budget:** idle under 0.5% CPU, at most 1 wake-up a second, at most 30 MB. While paused (screen
   asleep, locked, Low Power Mode) no timer runs at all. Details: `docs/performance.md`.
2. **Apple frameworks only.** No third-party dependencies.
3. **Targets:** `AashSprites`, `AashCore` and `AashAI` are libraries with no AppKit. Only `Sources/Aash`
   may import AppKit, EventKit, ServiceManagement or ApplicationServices. See `docs/architecture.md`.
4. **AppKit for all UI.** No SwiftUI.
5. **One clock.** `AnimationClock` is the only repeating timer, and it always sets `tolerance`.
   No polling loops and no `asyncAfter` chains.
6. **Swift 6 language mode.** App-target types are `@MainActor`. Library types are value types and
   `Sendable`. Use async/await.
7. **Copy patterns** from `docs/patterns.md` instead of inventing new ones.
8. **Tests use Swift Testing** (`import Testing`, `@Test`, `#expect`). XCTest isn't installed.
9. **No secrets in the repo.** API keys live in the Keychain; tests use the fixtures in `Tests/Fixtures`.
10. **Protected files:** don't edit `scripts/`, `.claude/` or `Package.swift` unless the card says so.

## Style

- One main type per file, named after it. Keep files under about 300 lines.
- No `!` force unwraps or `try!` outside tests. No `print` in committed code; use `Logger`
  (`docs/patterns.md#logging`).
- Comments explain why, not what. Every public declaration gets a one-line doc comment.
- Match the code around you: naming, spacing, how errors are handled.

## Where to look

| Need | Read |
|---|---|
| What the app does and doesn't do | `docs/product.md` |
| Targets, data flow, key types | `docs/architecture.md` |
| Code patterns to copy | `docs/patterns.md` |
| Budget, measuring, energy rules | `docs/performance.md` |
| The buddy's states and timings | `docs/behaviour.md` |
| Pixel art and rendering | `docs/sprites.md` |
| Status item, walking, Accessibility | `docs/menubar.md` |
| Gemini and Claude Code chat | `docs/ai.md` |
| Reminders and phrase parsing | `docs/reminders.md` |
| Why things are the way they are | `docs/decisions.md` |

## Compact instructions

When compacting, keep: the current card id, the files changed so far, the last `check.sh` output,
and any open problem. Drop file contents and old logs.
