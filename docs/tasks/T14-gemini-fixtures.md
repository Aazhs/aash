# T14 · Record Gemini responses

Phase 3 · Target: Tests/Fixtures · Risk: low · Detail: outline

## Goal

Real Gemini responses are saved as fixtures, and `docs/ai.md#observed-format` describes them
exactly, so T15 can build and test the client without guessing.

## Read first

- `docs/ai.md#gemini` (verified facts, and what this card records)
- `docs/WORKFLOW.md#gemini-key`

## Files (expected)

- create `Tests/Fixtures/gemini/reply.json`, `stream.txt`, `json-reply.json`, `two-turns.json`,
  `bad-key.json` (plus a `README.md` saying how each was made, with the exact `curl` minus the key)
- edit `docs/ai.md#observed-format`

## Sketch

- Needs `GEMINI_API_KEY` in the environment; stop with `RESULT: blocked` if it's empty. Pass it
  only as `-H "x-goog-api-key: $GEMINI_API_KEY"`; never print it.
- `curl -sS` POSTs to `https://generativelanguage.googleapis.com/v1beta/interactions`, model
  `gemini-3.5-flash-lite`, `"store": false`, for: a plain prompt; the same with `?alt=sse` and
  `"stream": true` (save the raw bytes, `--no-buffer`); `response_format` with the reminder schema
  from `docs/reminders.md`; a two-turn history; a deliberately wrong key.
- Before saving, check each file contains no key and no personal data.

## Done when (to be detailed by /plan-phase 3)

- [ ] All five fixtures exist and `docs/ai.md#observed-format` lists their exact field paths
- [ ] `./scripts/check.sh` prints `CHECK PASS`
