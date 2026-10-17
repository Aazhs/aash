# T26 · Final pass

Phase 5 · Target: all · Risk: medium · Detail: outline

## Goal

v1 is ready to live with: every budget measured and passing, the code reviewed against every rule
once more, the docs matching the code, and the installed copy up to date.

## Read first

- `CLAUDE.md`, `docs/performance.md`, `docs/architecture.md`, `docs/patterns.md#gotchas`

## Sketch

- Measure idle, walking, asleep and chat; all must pass.
- A whole-codebase review by the Opus reviewer: energy, threading, memory, rules. Fixes become
  cards before this one is done.
- Update `docs/architecture.md` (key types, settings keys) and `docs/product.md` where they drifted.
- `./scripts/install.sh`; turn on Open at Login if the user wants it.

## Done when (to be detailed by /plan-phase 5)

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Four `pass` rows in `docs/perf-log.md` from this card
- [ ] The reviewer's verdict is PASS for the whole codebase
