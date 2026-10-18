# T19 · Check: chat memory

Phase 3 · Target: none (measurement) · Risk: low · Detail: full

## Goal

Chat stays within budget: memory ≤ 50 MB while the popover is open and a reply streams, and back
under 35 MB 30 s after closing it. Idle is still within budget with all of Phase 3 in place. Results
are in `docs/perf-log.md`.

## Read first

- `docs/performance.md#budget`, `#measuring`, `#over-budget`
- `docs/tasks/T13-walking-budget.md`: same shape of card

## Files

- No source changes. `docs/perf-log.md` gets rows from `scripts/measure.sh`.

## Steps

1. Run `./scripts/run.sh`. Wait 5 s.
2. `./scripts/measure.sh 60 idle`. Report the line. A `FAIL` → `RESULT: blocked` with the likely
   cause from `docs/performance.md#over-budget`, as in T13.
3. Check a Gemini key is saved without reading it: ask the user in the manual check below (don't look
   in the Keychain or the environment).
4. Follow the manual check. Report each measure line.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] `docs/perf-log.md` has three new `pass` rows: `idle 60s`, `chat 15s`, and `idle 20s` after
  closing the chat. If chat can't be run (no key), say so and report `RESULT: blocked` with
  "needs a Gemini key in Settings".

## Manual check

1. Tell the user: "Left-click the buddy, ask a question that gets a long answer (for example
   'Explain how rainbows form in detail'), and answer this prompt as soon as the reply starts
   streaming."
2. When they answer, run `WARMUP=0 ./scripts/measure.sh 15 chat`.
3. Tell the user: "Close the chat now, then don't touch anything for 30 seconds." Wait 30 s
   (one `sleep 30` run in the foreground is fine here), then run `./scripts/measure.sh 20 idle`.
4. Ask: "Here are the numbers: <the three lines>. Did the chat feel quick, and did the buddy cheer
   when the reply finished?" The memory on the last idle line must be ≤ 35 MB. If it isn't,
   report `RESULT: blocked`, quote the line, and suggest `/card fix: chat popover keeps memory`
   (look for a retained `ChatViewController`, popover or stream task).

## Out of scope

- Fixing anything. Measuring Claude Code (T24).

## Notes

- `measure.sh chat` only fails on memory (> 50 MB); CPU and wake-ups are unlimited for that state.
- The 35 MB "after close" limit is in `docs/performance.md` but `measure.sh idle` checks 30 MB; the
  card applies 35 MB by hand to the last line, and also logs the stricter script verdict. A script
  `FAIL` with memory between 30 and 35 MB is acceptable here; say so in the report.
