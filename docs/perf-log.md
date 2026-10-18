# Performance log

`scripts/measure.sh` adds a row here every time it runs. Budgets: [performance.md](performance.md#budget).

| Date | Commit | State | CPU | Wake-ups | Memory | Result |
|---|---|---|---|---|---|---|
| 2026-10-18 00:26 | 3277a9c | idle 20s (Phase 0 skeleton) | 0.00% | 0.00/s | 11.0 MB | pass |
| 2026-10-18 02:13 | b403536 | idle 30s | 0.00% | 0.00/s | 11.0 MB | pass |
| 2026-10-18 02:19 | b403536 | idle 30s | 0.10% | 0.00/s | 11.0 MB | pass |
| 2026-10-18 02:28 | 5b59df8 | idle 60s | 0.05% | 0.00/s | 12.0 MB | pass |
| 2026-10-18 02:29 | 5b59df8 | asleep 30s | 0.01% | 0.00/s | 12.0 MB | pass |
| 2026-10-18 21:36 | 0377725 | idle 60s | 0.03% | 0.00/s | 12.0 MB | pass |
| 2026-10-18 21:37 | 0377725 | walking 10s | 2.63% | 0.00/s | 18.0 MB | FAIL |
| 2026-10-18 21:40 | 0377725 | walking 10s | 1.23% | 0.00/s | 18.0 MB | pass |
