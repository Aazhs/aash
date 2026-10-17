# T07 · Check: idle budget

Phase 1 · Target: none (measurement) · Risk: low · Detail: full

## Goal

Prove Phase 1 is within budget before walking adds more: idle and paused measurements are
recorded in `docs/perf-log.md` and both pass. If either fails, the card reports why instead of
fixing it.

## Read first

- `docs/performance.md#budget`, `#measuring`, `#over-budget`

## Files

- No source changes. `scripts/measure.sh` adds rows to `docs/perf-log.md` by itself.

## Steps

1. Run `./scripts/run.sh`.
2. Run `./scripts/measure.sh 60 idle`. Don't touch the buddy while it runs.
3. If it printed `FAIL`: look at `docs/performance.md#over-budget` and the code it points to.
   Report `RESULT: blocked` with the measure line and the likely cause, with file and line. Don't
   change code; a fix card comes next.
4. If it passed, report `RESULT: done` with the measure line.

## Rules

- Measuring only. Don't edit any source file, script or setting.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` (nothing changed, so it should)
- [ ] `docs/perf-log.md` has a new `idle 60s` row marked `pass`
- [ ] After the manual check, it also has an `asleep 30s` row marked `pass`

## Manual check

1. Ask the user to turn on Low Power Mode and answer when it's on.
2. Run `./scripts/measure.sh 30 asleep`.
3. Ask the user to turn Low Power Mode off again.
4. Ask: "The paused measurement said: <the line>. Did the buddy stay still while Low Power Mode
   was on?" If the line says `FAIL`, mark the card `blocked` with the line as the reason, and tell
   the user to run `/card fix: paused budget` with that line.

## Out of scope

- Fixing anything. Measurements over budget become their own card.
