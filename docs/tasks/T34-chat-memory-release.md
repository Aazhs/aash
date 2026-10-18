# T34 · Give chat memory back after closing

Phase 3 · Target: Aash · Risk: low · Detail: full

## Goal

After the chat popover closes, Aash hands its freed memory back to macOS straight away, so the
footprint falls under 35 MB within 30 s of closing (`docs/performance.md`, `chat` row). T19 then
passes.

## Cause (found while writing this card)

T19 measured 38 MB, 30 s after closing the chat. The limit is 35 MB. On the same running app:

- `heap <pid>` found **no** `ChatViewController`, `NSPopover`, `NSTextView` or `GeminiProvider`
  left alive, and `leaks` found 20 KB. Nothing is retained. `ChatPopoverController.popoverDidClose`
  already cancels the stream and drops the popover and view controller.
- `footprint <pid>` showed **21 MB dirty in "Malloc Small"**, while the whole heap held about
  15 MB of live objects. The rest is freed memory the allocator keeps for reuse instead of returning
  to the system. Six minutes later it had drifted down to 33 MB on its own.
- What stays live is one-time framework state: ICU (text layout), CoreSVG (button and popover
  symbols), CFNetwork. It is small and loaded once.

So the fix is to ask the allocator to release free pages once the chat's objects are gone.
`malloc_zone_pressure_relief(nil, 0)` (libmalloc, `<malloc/malloc.h>`) does exactly that, for all
zones.

## Read first

- `docs/performance.md#budget`: the `chat` row
- `docs/patterns.md#gotchas`: `@Sendable` closures and `RunLoop.main`
- `Sources/Aash/ChatPopoverController.swift`: `popoverDidClose`

## Files

- edit `Sources/Aash/ChatPopoverController.swift`: release free memory after close
- edit `docs/performance.md`: one row in the "Over budget?" table
- edit `docs/decisions.md`: one row

## Interfaces

```swift
// ChatPopoverController.swift, new private helper (no other API changes):
/// Returns freed malloc pages to the system once the chat's objects are gone.
private static func releaseFreedMemory()
```

## Steps

1. Add `import Darwin` to `ChatPopoverController.swift`, if `malloc_zone_pressure_relief` isn't
   visible through AppKit.
2. Add `releaseFreedMemory()`. It calls `RunLoop.main.perform { _ = malloc_zone_pressure_relief(nil, 0) }`.
   Put a why-comment on the `perform` line: the views are freed when the autorelease pool drains at
   the end of this run-loop turn, so the relief has to run on the next turn. The closure touches
   no main-actor state, so it needs no `assumeIsolated`.
3. In `popoverDidClose`, call `Self.releaseFreedMemory()` as the last line, after `onEvent(.chatClosed)`.
4. `docs/performance.md`, "Over budget?" table: add the row
   `| Memory stays high after chatting, but heap shows no chat objects | Freed malloc pages not yet returned; ChatPopoverController asks for them back on close (T34) |`
   right after the existing "Memory grows after chatting" row.
5. `docs/decisions.md`: append a row dated 2026-10-19:
   `Closing the chat calls malloc_zone_pressure_relief once, on the next run-loop turn.` · reason:
   `T19: 38 MB after close with no chat objects alive; 21 MB of it was freed Malloc Small pages.`
   Match the table's existing column layout.

## Rules

- One clock (CLAUDE.md rule 5). This is a single `RunLoop.main.perform`, not a timer, not
  `asyncAfter`, and it doesn't repeat. Don't add a delay or a retry.
- App-target types stay `@MainActor`. No `@unchecked Sendable` and no `nonisolated(unsafe)`.
- No `print`. No logging is needed here.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] `grep -rn "malloc_zone_pressure_relief" Sources` finds exactly one call, in `ChatPopoverController.swift`
- [ ] `grep -rn "Timer(\|asyncAfter" Sources/Aash` finds only `AnimationClock.swift`
- [ ] No tests: this behaviour can only be measured on the running app (Manual check)

## Manual check

The orchestrator does this with the user, in order:

1. Run `./scripts/run.sh`.
2. Tell the user: "Left-click the buddy, ask 'Explain how rainbows form in detail', wait for the
   reply to finish, close the chat. Do that three times, then answer this and leave the Mac alone."
3. Run `heap $(pgrep -x Aash) | grep -cE "ChatViewController|NSPopover "`. It must print `0`.
4. Run `WARMUP=30 ./scripts/measure.sh 20 idle`. The memory on that line must be ≤ 35 MB. The
   script's own verdict uses 30 MB, so FAIL with 30–35 MB is acceptable here.
5. If it's over 35 MB: run `footprint $(pgrep -x Aash) | head -12`, report `RESULT: blocked` with
   that output and the measure line, and stop. Don't try other fixes. The remaining options are
   budget decisions for the user.
6. Ask: "After three chats: <the measure line>. Does the chat still open and reply normally?"

## Out of scope

- Changing the budget numbers in `docs/performance.md`.
- Switching `GeminiProvider` away from `URLSession.shared`, or invalidating sessions.
- Any chat UI change: Markdown, growing input, newlines. Those are separate follow-ups.
- Re-running T19. It runs next, as its own card.

## Notes

- `malloc_zone_pressure_relief` returns the number of bytes released (`Int`). Discard it with `_ =`.
- Calling it before the views are freed releases almost nothing, which is why step 2 waits for the
  next run-loop turn.
- `RunLoop.main.perform` takes a `@Sendable` closure in Swift 6. Calling a C function from it is fine.
