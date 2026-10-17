# Performance

The app is only welcome if you never notice it. On an 8 GB M1 MacBook Air that's already busy, that
means almost no CPU, almost no wake-ups and a small, steady amount of memory.

## Budget

| State | How to get there | CPU (avg) | Wake-ups | Memory |
|---|---|---|---|---|
| `idle` | Leave it alone, walking off | < 0.5% | ≤ 1/s | ≤ 30 MB |
| `walking` | Menu → Walk now | < 2% | ≤ 12/s | ≤ 30 MB |
| `asleep` | Turn on Low Power Mode, or lock the screen while measuring | ≤ 0.1% | ≤ 0.2/s | ≤ 30 MB |
| `chat` | Popover open, one reply streaming | spikes are fine | — | ≤ 50 MB, and back under 35 MB within 30 s of closing |

`./scripts/measure.sh <seconds> <state>` checks a running app against this table and adds a row to
[perf-log.md](perf-log.md). The skeleton measured 0.00% CPU, 0 wake-ups/s and 11 MB idle on
18 Oct 2026, so there's room, but it goes fast.

## Rules that keep it there

1. **One clock.** `AnimationClock` is the only repeating timer. The engine asks it for
   `.stopped`, `.once(at:)` or `.every(seconds:)`; nothing else schedules work.
2. **Idle is still.** Idle shows one frame and wakes only to blink (about every 4.5 s) or to start
   a walk. No breathing, no bobbing.
3. **Paused means stopped.** Screen asleep, locked, Low Power Mode, or the status item hidden:
   `.stopped`, with no timer at all. Night is a single `.once(at: 07:00)`.
4. **Tolerance on every timer.** 20% for frame ticks, 0.5 s for one-off ticks. macOS batches
   tolerant timers with other wake-ups.
5. **Draw once, then move pixels on the GPU.** Sheets are built once per appearance. A frame change
   is a `contentsRect` change; walking is a position change. Both go inside `CATransaction` with
   actions disabled. Nothing overrides `draw(_:)`.
6. **Low frame rates.** 8 fps walking, 4 fps waving. Pixel art looks right at low rates.
7. **Nothing polls.** Use notifications (`NSWorkspace`, `EKEventStoreChanged`, power state,
   occlusion) or a single scheduled tick at a known time.
8. **Build UI when it's shown, free it when it closes.** The chat popover and the settings window
   are created on open and released on close. Cancel streaming tasks on close.
9. **Network only on demand.** Nothing is fetched in the background. No analytics, no update checks.
10. **AppKit only.** SwiftUI would add memory that doesn't go away.
11. **Cheap logging.** `Logger` at `.debug` costs almost nothing when nobody's streaming logs.
    Never build log strings by hand in a per-frame path.

## Measuring

1. `./scripts/run.sh` (or launch the installed copy).
2. Put the app in the state you want (table above). Wait 5 s.
3. `./scripts/measure.sh 60 idle` (or `walking`, `asleep`, `chat`). For `asleep`, start the command,
   then turn on Low Power Mode or lock the screen until it finishes.
4. Read the one-line result; the row is already in `perf-log.md`.

Activity Monitor tells the same story by eye: the **Energy** tab shows Energy Impact and **Idle
Wake Ups** for Aash; the **Memory** tab shows its footprint.

Gate cards (T07, T13, T19) run these measurements at the end of each phase. A result over budget
gets a fix card (`/card fix: ...`) before the next phase starts.

## Over budget?

Usual suspects, most likely first:

| Symptom | Likely cause |
|---|---|
| Wake-ups high while idle | A blink or walk schedule recomputed as `.every` instead of `.once`; a second timer; an observer that triggers ticks |
| CPU high while idle | An implicit layer animation (missing `setDisableActions`); a sheet rebuilt every frame |
| Memory grows after chatting | The popover, its view controller or the stream task is still referenced |
| CPU high while paused | A path that doesn't check `paused`; the clock not stopped |
