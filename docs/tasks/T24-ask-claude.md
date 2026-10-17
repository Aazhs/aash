# T24 · Ask Claude

Phase 5 · Target: AashAI + Aash · Risk: medium · Detail: outline

## Goal

An "Ask Claude" button in the chat sends the current question to Claude through the Claude Code
CLI, using your existing plan. It starts with a cost check, so it only ships if it stays light.

## Read first

- `docs/ai.md#claude-code-ask-claude-phase-5`
- `docs/patterns.md#streaming`

## Files (expected)

- create `Sources/AashAI/ClaudeCodeProvider.swift` (`Process`, stream-json parsing)
- create `Tests/AashAITests/ClaudeCodeProviderTests.swift` (parsing recorded stream-json lines)
- create `Tests/Fixtures/claude/stream.jsonl` (recorded once by the card)
- edit the chat view controller (the button), `AppSettings` (on or off, default off)

## Sketch

- Step 1 (spike): run the command from `docs/ai.md` once with `/usr/bin/time -l`; record the time
  to the first text and the peak memory in `docs/ai.md`. More than 5 s or 300 MB → keep it as an
  explicit button only, and say so in the docs.
- Find `claude` at start-up (`/usr/bin/env which claude` from a login shell environment); hide the
  button when it's missing.

## Done when (to be detailed by /plan-phase 5)

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Manual: Ask Claude answers a question in the popover; closing the popover kills the process
