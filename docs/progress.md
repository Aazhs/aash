# Progress

One row per finished card, added by `/next`. It shows where cheaper models did well and where they
needed help, so card models can be tuned.

| Date | Card | Implementer model | Fix rounds | Note |
|---|---|---|---|---|
| 2026-10-18 | Phase 0 (setup) | opus (main session) | — | Skeleton, scripts, agents, skills, docs and cards. Toolchain quirk found and fixed (decisions.md). |
| 2026-10-18 | T01 Sprite art | haiku | 0 | Passed review first time; grids ported by script and checked against sprites.md. |
| 2026-10-18 | T03 Behaviour engine | sonnet | 1 | Review fixed clock-step clamp and click-while-walking-out; 42 tests. |
| 2026-10-18 | T02 Sprite sheet | sonnet | 0 | Passed review first time; 10 pixel-readback tests. SpriteSheet not Sendable yet (T04 may need it). |
| 2026-10-18 | T04 Status item | sonnet | 0 | Resumed after interrupted run; Opus review passed; idle 0.10% CPU, 11.0 MB. |
| 2026-10-18 | T05 Pause when nobody's looking | sonnet | 0 | Passed review first time; Low Power pause/resume confirmed in log; occlusion does not fire on macOS 27 (noted in menubar.md). |
| 2026-10-18 | T06 Menu and open at login | haiku | 0 | Passed review first time; menu and login item confirmed by user. |
| 2026-10-18 | T07 Check: idle budget | haiku | 0 | Passed review first time; idle 0.05% CPU, 12.0 MB; asleep 0.01% CPU, 0 wake-ups. |
