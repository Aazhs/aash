# T26 · Final pass

Phase 5 · Target: all · Risk: medium · Detail: full

## Goal

v1 is ready to live with. Every budget is measured and passes. The whole codebase has been
reviewed once more against every rule. The docs match the code, and the installed copy in
`~/Applications` is current.

## Read first

- `CLAUDE.md` (hard rules and style), `docs/performance.md#budget`
- `docs/architecture.md#key-types` and `#settings-keys`, `docs/product.md#v1-does`
- `docs/patterns.md#gotchas`

## Files

- edit `docs/architecture.md`: only where it no longer matches the code
- edit `docs/product.md`: only where it no longer matches the code
- edit `docs/patterns.md#gotchas`: at most one line per real trap found
- Source files only for fixes the review asks for (see "Review" below)

## Steps

1. **Key types:** for every file in `Sources/*/`, check that its main type has a row in
   `docs/architecture.md#key-types`, with the right file and the card that made it. Check that
   every row names a file that exists. Add missing rows and fix wrong ones. Don't rewrite rows
   that are right.
2. **Settings keys:** every key string in `Sources/Aash/AppSettings.swift` has a row with the
   same type and default. There should be five: `walkingEnabled`, `walkDistance`,
   `freeWalkEnabled`, `chatModel`, `askClaudeEnabled`.
3. **Logging categories:** `grep -rhn 'category: "' Sources` and make the category list in
   `docs/architecture.md#logging` match it.
4. **Product:** read `docs/product.md#v1-does` and `#v1-doesnt` against the app as built. That
   includes Ask Claude (T24), reminders alerting on the Mac only (`decisions.md`, 19 Oct) and the
   app icon (T25). Fix only the sentences that are now wrong.
5. **Rule sweep:** run these and fix anything they find in `Sources/`, or list it in the report
   if fixing would need more than a few lines:
   - `grep -rn "Timer(" Sources`: only `AnimationClock.swift`
   - `grep -rn "asyncAfter\|DispatchQueue" Sources`: nothing
   - `grep -rn "try!\|print(" Sources`: nothing
   - `grep -rnE "[a-zA-Z0-9_)\]]![^=]" Sources --include=*.swift`: read each hit. A force
     unwrap is allowed only where a comment says why it's a constant (like the Gemini base URL).
   - `grep -rln "import AppKit\|import EventKit\|import ServiceManagement\|import ApplicationServices" Sources`:
     only files in `Sources/Aash`
   - `grep -rn "SwiftUI" Sources`: nothing
   - `wc -l Sources/*/*.swift`: list any file over 300 lines in the report. Don't split it in
     this card.
6. Run `./scripts/check.sh`.

## Review

The reviewer for this card (Opus) reviews **the whole of `Sources/`**, not only the diff. It
checks energy (timers, tolerance, pausing), threading (`@MainActor`, `Sendable`, task
cancellation), memory (what the popover and settings window keep after closing), the `claude`
child process (T24, T37), and the CLAUDE.md rules.

- Fixes of a few lines in one or two files go back to this card's implementer, as usual.
- Anything bigger: the orchestrator sets this card to `blocked`, with "review found: …" as the
  reason, and tells the user to run `/card fix: …` for each item. T26 is done only after those
  cards are done and a re-review passes.

## Rules

- This card fixes and documents. It adds no features and changes no behaviour, except to fix a
  rule break.
- The protected files (`scripts/`, `.claude/`, `Package.swift`) don't change.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] Steps 1 to 5 are done. The report lists what changed in the docs, and anything step 5
      found that wasn't fixed.
- [ ] The reviewer's verdict for the whole codebase is PASS
- [ ] The manual check below gives four `pass` rows in `docs/perf-log.md` (idle, walking,
      asleep, chat), plus the after-chat row at or under 35 MB

## Manual check

The orchestrator does these in order and puts each measure line in the progress note. A FAIL
means: stop, set the card to `blocked` with the line as the reason, and suggest
`/card fix: <state> over budget`.

1. **Idle:** `./scripts/run.sh`, wait 30 s, then `./scripts/measure.sh 60 idle`. It must say
   `pass`. Memory is at most 30 MB with no chat opened yet.
2. **Walking:** ask the user to right-click the buddy and choose **Walk now**, then right away
   run `./scripts/measure.sh 10 walking`. It must say `pass`.
3. **Asleep:** ask the user to turn on Low Power Mode (System Settings → Battery). Then run
   `./scripts/measure.sh 60 asleep`, which must say `pass`. Then ask them to turn it off again.
4. **Chat:** ask the user to open the chat and send `tell me a short story about a pixel cat`.
   While it streams, run `./scripts/measure.sh 15 chat`, which must say `pass`. Then ask them to
   close the chat and run `WARMUP=30 ./scripts/measure.sh 20 idle`. The script prints FAIL
   against its 30 MB idle limit; the after-chat limit is 35 MB (`performance.md#budget`, chat
   row), so read the memory number and check it's at most 35.
5. **Sweep:** ask the user to try each of these and answer "Looks right" or "Something's off",
   with a note:
   - light and dark menu bar (System Settings → Appearance)
   - a crowded bar: a stretch walk and, if on, a free walk still look right with little room
   - Reduce Motion on (Accessibility → Display): no walks, blinks still happen
   - "Automatically hide and show the menu bar" on (Control Centre): the buddy is there when the
     bar shows, and walks don't leave a window behind
6. **Install:** run `./scripts/install.sh`. Ask whether to turn on Open at Login (Settings →
   "Open at login"). The user does it themselves.

## Out of scope

- New features, the "later ideas" in `product.md`, or a notch.
- Rewriting docs that are already right.
- Splitting long files: list them in the report.

## Notes

- Since T23 the `EKEventStore` is made at launch when Reminders access is granted, so fresh idle
  memory may be above the 12 MB measured in phase 3. Up to 30 MB passes.
- Weekly Claude usage was at 97% on 19 Oct. The Opus whole-codebase review is the most expensive
  step of phase 5, so run it after the limit resets if it's close.
