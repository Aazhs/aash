# T14 · Record Gemini responses

Phase 3 · Target: Tests/Fixtures · Risk: low · Detail: full

## Goal

Real Gemini responses are saved as fixtures in `Tests/Fixtures/gemini/`, and
`docs/ai.md#observed-format` describes them exactly (field paths, SSE framing, error body), so T15
can build and test the client without guessing.

## Read first

- `docs/ai.md#gemini` (the verified table, and "What T14 records")
- `docs/WORKFLOW.md#gemini-key`
- `docs/reminders.md#gemini-fallback-schema-t22` (the schema for the JSON fixture)

## Files

- create `Tests/Fixtures/gemini/reply.json`
- create `Tests/Fixtures/gemini/stream.txt`
- create `Tests/Fixtures/gemini/json-reply.json`
- create `Tests/Fixtures/gemini/two-turns.json`
- create `Tests/Fixtures/gemini/bad-key.json`
- create `Tests/Fixtures/gemini/README.md`: for each fixture, the request body and the `curl`
  command, with the key replaced by `$GEMINI_API_KEY`
- edit `docs/ai.md`: fill in `### Observed format`

## Steps

1. Check the key without printing it: `[ -n "$GEMINI_API_KEY" ] && echo set || echo empty`. If it
   prints `empty`, stop and report `RESULT: blocked` with the note "export GEMINI_API_KEY in the
   terminal Claude Code was started from, then set this card back to todo". Do nothing else.
2. Send every request with
   `curl -sS --max-time 60 -H "x-goog-api-key: $GEMINI_API_KEY" -H "Content-Type: application/json"`
   to `https://generativelanguage.googleapis.com/v1beta/interactions`, with a body from a
   here-doc. Never `echo`, `set -x`, or `env` the key; never put it in a file or in the command text.
   Use `-w '\n%{http_code}\n'` only when you need the status; keep the status out of the fixture file
   and note it in the README.
3. Record `reply.json` (plain prompt). Body:
   `{"model":"gemini-3.5-flash-lite","input":"Say hello in five words.","system_instruction":"You are Aash, a small pixel buddy. Be brief.","store":false,"generation_config":{"thinking_level":"minimal","max_output_tokens":1024}}`
4. Record `stream.txt`: the same body plus `"stream":true`, URL ending `?alt=sse`, with
   `--no-buffer`, raw bytes saved unchanged (`> stream.txt`).
5. Record `json-reply.json`: input
   `"Remind me to call mum tomorrow at 7pm. Today is Sunday 2026-10-18, 10:00."`, no streaming, plus
   `"response_format":{"type":"text","mime_type":"application/json","schema":<the schema from docs/reminders.md>}`.
6. Record `two-turns.json`: `input` is an array of steps, which is how the docs describe a stateless
   conversation:
   `[{"type":"user_input","content":[{"type":"text","text":"My name is Sam."}]},{"type":"model_output","content":[{"type":"text","text":"Nice to meet you, Sam!"}]},{"type":"user_input","content":[{"type":"text","text":"What is my name?"}]}]`
   with `"store":false`. If the API rejects that shape (HTTP 400), try `[{"role":"user","content":"…"},…]`
   and record whichever shape works; say in the README which one was rejected and its error message.
   The reply should mention "Sam".
7. Record `bad-key.json`: the plain request with `-H "x-goog-api-key: not-a-real-key"` (a literal fake
   string, not the real key). Save the body; note the HTTP status in the README.
8. Safety check before finishing: `grep -rniE "AIza|api[_-]?key[\"': ]+[A-Za-z0-9_-]{20,}" Tests/Fixtures`
   must find nothing, and `grep -rnF "$GEMINI_API_KEY" Tests/Fixtures` must find nothing. Read each
   fixture: no names, emails or file paths belonging to the user.
9. Pretty-print nothing: keep the bytes exactly as received (except `reply.json`, `json-reply.json`,
   `two-turns.json` and `bad-key.json` may be piped through `python3 -m json.tool` if they arrive
   minified, so a person can read them; say so in the README).
10. Fill in `### Observed format` in `docs/ai.md`, one short table or list each for:
    - reply: the JSON path to the reply text (for example `steps[i].content[j].text` where
      `steps[i].type == "model_output"` and `content[j].type == "text"`), `status` value, and whether
      thinking steps appear in `steps` and what their `type` is
    - stream: whether frames have an `event:` line, the `event_type` values seen in order, the exact
      path of a text chunk (`delta.text` where `delta.type == "text"`), and how the stream ends
    - json reply: where the JSON string is, and that it parses against the schema
    - two-turn: the input shape that worked
    - bad key: HTTP status and the JSON path to the message (for example `error.message`,
      `error.status`)
    - the fixtures' file names
    Also correct the table at the top of `### What's verified` if a row proved wrong.

## Rules

- Never print, log, save or commit the key (CLAUDE.md rule 9). Only the `-H "x-goog-api-key: $GEMINI_API_KEY"` form.
- Don't edit anything in `Sources/`, `Tests/*Tests` or `scripts/`.
- Free-tier requests may be used by Google to improve its products: send only the harmless prompts above.

## Done when

- [ ] The five fixture files and `README.md` exist, and the safety greps in step 8 find nothing
- [ ] `docs/ai.md#observed-format` lists the exact field paths for all five
- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] If a request fails for a reason other than the deliberate bad key (HTTP 429, 5xx, network),
  report `RESULT: blocked` with the status and error text; don't invent a fixture.

## Out of scope

- A 429 fixture. T15 tests quota with a synthetic response.
- Any Swift code.

## Notes

- Model ids in Google's examples may differ from ours (`gemini-3.8-flash` appears in the docs); keep
  `gemini-3.5-flash-lite` from `docs/ai.md`. If it returns 404, report it; don't switch models.
- The docs only show SDK samples, so the exact bytes matter: keep them unedited.
