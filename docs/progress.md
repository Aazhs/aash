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
| 2026-10-18 | T08 Stretch walk | sonnet → opus | 3 review, 2 manual | Walk works; macOS slides the item ~0.3 s on resize, so the buddy appears to snap at start and end. Accepted by user; docs/menubar.md says home stays put, which is untrue on macOS 27. Fix later. |
| 2026-10-18 | T09 Walk safety | sonnet | 0 | Passed review first time. Manual check: after lock/unlock the buddy returns home but the user reports the animation stopped; unconfirmed (no Aash log lines, idle-lock not verified). Suspect SystemEvents resume path (T05); check in T13. |
| 2026-10-18 | T10 Accessibility probe | sonnet | 0 | Passed review first time. Report pasted into menubar.md: extras finds other status items (some owned by MenuBarAgent), agentItems redundant, appMenus sensible. Free walk is viable. |
| 2026-10-18 | T11 Free-space maths | sonnet | 0 | Passed review first time. Blocked-range overlap test is inclusive at both ends; FreeWalkPlan has no public init yet (T12 may need one). |
| 2026-10-18 | T12 Free walk | opus | 2 review, 1 manual | Review fixes: sprite sheet follows status button appearance; rescan on Space change. Manual: buddy covers the empty bar and vanishes (not snaps) for ~33 pt at walk start/end by design; ~8 pt gap left of the walk area is the margin. Earlier snap was the T08 stretch fallback. Full-screen and click checks not confirmed. |
| 2026-10-18 | T27 Respect Reduce Motion | sonnet | 0 | Passed review first time. Manual check OK: Walking greys out under Reduce Motion and Walk now works after turning it off. |
| 2026-10-18 | T13 Check: walking budget | haiku | 0 | Idle 60s 0.03% CPU, 12.0 MB. Walking 10s: first run 2.63% (fail, user measured late), rerun 1.23% CPU, 18.0 MB, pass. Both rows kept in perf-log. |
| 2026-10-18 | T28 Walk out of the icon | sonnet | 3 fix rounds (manual: left edge, targets band, rescan range) | Edited FreeSpace beyond the card at the user's request: no margin at the menus edge; targets are the far-left 30 pt band. First-try walk failure was the Accessibility prompt. User reports the walk breaks on window change: card T30. |
| 2026-10-18 | T29 Bigger buddy, solid outline | sonnet | 2 review, 1 manual | Manual: user wanted no outline at all, so `.dark` has none (card asked for solid #ede6f2); outline pass kept and tested, unused. Stale: menubar.md:108 says 15 pt Retina. |
| 2026-10-18 | T30 Free walk after window change | sonnet | 0 | Passed review first time. Manual OK: app switch narrowed visible to -481, buddy kept walking and rested at the new edge (log confirmed). |
| 2026-10-18 | T14 Record Gemini responses | haiku | 0 | Passed review first time. Step-array two-turn shape accepted; bad key is HTTP 400 with the message at `[0].error.message`. Corrected the `output_text` bullet in ai.md. |
| 2026-10-19 | T31 Chat types and SSE parser | sonnet | 0 | Passed review first time. 71 tests, 0 warnings. |
| 2026-10-19 | T15 Gemini client | sonnet | 1 review | Fix: StubURLProtocol state moved from nonisolated(unsafe) vars into a locked Box. bad-key.json is a one-element array; parser accepts both. Stub needs Content-Type text/event-stream to stream. Left over: `URL(string:)!` constant default baseURL in GeminiProvider.swift:18 breaks the no-force-unwrap rule; fix in T26. |
| 2026-10-19 | T32 Chat wording | haiku | 0 | Passed review first time. 93 tests. |
| 2026-10-19 | T16 Keychain store | haiku | 0 | Passed review first time. 100 tests; no Keychain dialog during tests, test items cleaned up. |
