# Board

`/next` takes the first `todo` row whose `Needs` are all `done`. Status is one of `todo`, `doing`,
`done`, `blocked` (with a reason). `Model` picks the implementer, `Reviewer` the reviewer. Cards
with the same `Parallel` group run together. Phases 4–5 are outlines until `/plan-phase N` runs.

| ID | Card | Phase | Model | Reviewer | Needs | Parallel | Status |
|---|---|---|---|---|---|---|---|
| T01 | [Sprite art](T01-sprite-art.md) | 1 | haiku | sonnet | — | P1 | done |
| T02 | [Sprite sheet](T02-sprite-sheet.md) | 1 | sonnet | sonnet | T01 | — | done |
| T03 | [Behaviour engine](T03-behaviour-engine.md) | 1 | sonnet | sonnet | — | P1 | done |
| T04 | [Status item](T04-status-item.md) | 1 | sonnet | opus | T02, T03 | — | done |
| T05 | [Pause when nobody's looking](T05-pause.md) | 1 | sonnet | sonnet | T04 | — | done |
| T06 | [Menu and open at login](T06-menu-and-login.md) | 1 | haiku | sonnet | T04 | — | done |
| T07 | [Check: idle budget](T07-idle-budget.md) | 1 | haiku | sonnet | T05, T06 | — | done |
| T08 | [Stretch walk](T08-stretch-walk.md) | 2 | sonnet | sonnet | T07 | — | done |
| T09 | [Walk safety](T09-walk-safety.md) | 2 | sonnet | sonnet | T08 | — | done |
| T10 | [Accessibility probe](T10-accessibility-probe.md) | 2 | sonnet | sonnet | T09 | — | done |
| T11 | [Free-space maths](T11-free-space.md) | 2 | sonnet | sonnet | T10 | — | done |
| T12 | [Free walk](T12-free-walk.md) | 2 | opus | opus | T11 | — | done |
| T27 | [Respect Reduce Motion](T27-reduce-motion.md) | 2 | sonnet | sonnet | T12 | — | done |
| T13 | [Check: walking budget](T13-walking-budget.md) | 2 | haiku | sonnet | T27 | — | done |
| T28 | [Walk out of the icon](T28-walk-out-of-icon.md) | 2 | sonnet | sonnet | T13 | — | done |
| T29 | [Bigger buddy, solid outline](T29-bigger-buddy.md) | 2 | sonnet | sonnet | T28 | — | done |
| T30 | [Free walk after window change](T30-walk-after-window-change.md) | 2 | sonnet | sonnet | T29 | — | done |
| T14 | [Record Gemini responses](T14-gemini-fixtures.md) | 3 | haiku | sonnet | T13 | — | done |
| T31 | [Chat types and SSE parser](T31-chat-types-sse.md) | 3 | sonnet | sonnet | T13 | — | done |
| T15 | [Gemini client](T15-gemini-client.md) | 3 | sonnet | sonnet | T14, T31 | — | done |
| T32 | [Chat wording](T32-chat-wording.md) | 3 | haiku | sonnet | T31 | — | done |
| T16 | [Keychain store](T16-keychain.md) | 3 | haiku | sonnet | T13 | — | done |
| T18 | [Settings window](T18-settings-window.md) | 3 | sonnet | sonnet | T16 | — | done |
| T17 | [Chat popover](T17-chat-popover.md) | 3 | sonnet | sonnet | T15, T32, T18 | — | done |
| T33 | [Clipboard buttons, Chat menu item, reopen](T33-chat-clipboard-and-menu.md) | 3 | sonnet | sonnet | T17 | — | done |
| T19 | [Check: chat memory](T19-chat-budget.md) | 3 | haiku | sonnet | T33 | — | blocked: 38 MB idle after chat closed (limit 35) |
| T20 | [Reminder phrase parser](T20-reminder-parser.md) | 4 | sonnet | sonnet | T19 | — | todo |
| T21 | [Reminders store](T21-reminders-store.md) | 4 | sonnet | sonnet | T19 | — | todo |
| T22 | [Reminders from chat](T22-chat-reminders.md) | 4 | sonnet | sonnet | T20, T21 | — | todo |
| T23 | [Wave before due](T23-due-wave.md) | 4 | sonnet | sonnet | T21 | — | todo |
| T24 | [Ask Claude](T24-ask-claude.md) | 5 | sonnet | sonnet | T23 | — | todo |
| T25 | [App icon](T25-app-icon.md) | 5 | haiku | sonnet | T23 | — | todo |
| T26 | [Final pass](T26-final-pass.md) | 5 | sonnet | opus | T24, T25 | — | todo |
