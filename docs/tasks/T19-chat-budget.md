# T19 · Check: chat memory

Phase 3 · Target: none (measurement) · Risk: low · Detail: outline

## Goal

Chat stays within budget: memory while the popover is open, and memory back near idle 30 s after
closing. Idle is still within budget with all of Phase 3 in place.

## Read first

- `docs/performance.md#budget`, `#measuring`, `#over-budget`

## Sketch

- `./scripts/measure.sh 60 idle` first.
- Manual: the user opens the chat and asks a question; the orchestrator runs
  `WARMUP=0 ./scripts/measure.sh 15 chat`; the user closes it; wait 30 s; `./scripts/measure.sh 20 idle`.

## Done when (to be detailed by /plan-phase 3)

- [ ] Three new `pass` rows in `docs/perf-log.md`, or the card is `blocked` with the failing line
