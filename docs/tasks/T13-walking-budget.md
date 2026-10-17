# T13 · Check: walking budget

Phase 2 · Target: none (measurement) · Risk: low · Detail: full

## Goal

Walking stays within budget, and walks leave nothing running afterwards. Results are in
`docs/perf-log.md`.

## Read first

- `docs/performance.md#budget`, `#measuring`, `#over-budget`

## Files

- No source changes.

## Steps

1. Run `./scripts/run.sh`.
2. Run `./scripts/measure.sh 60 idle`. Walks may start during the minute; that's realistic.
3. Report the line. If it says `FAIL`, report `RESULT: blocked` with the likely cause, as in T07.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] `docs/perf-log.md` has a new `idle 60s` row, plus a `walking 10s` row from the manual check,
  both `pass`

## Manual check

1. Tell the user: "Right-click → Walk now, then answer straight away."
2. When they answer, run `WARMUP=0 ./scripts/measure.sh 10 walking`.
3. If free walk is on, ask for one more Walk now and measure the same way.
4. Ask: "Here are the walking numbers: <lines>. After the walk, did the icon go back to normal?"
   A `FAIL` blocks the card with the line as the reason; suggest `/card fix: walking budget`.

## Out of scope

- Fixing anything.
