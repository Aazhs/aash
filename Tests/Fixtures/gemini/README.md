# Gemini fixtures

Real responses from the Gemini API, recorded with `curl` on 18 Oct 2026 for model
`gemini-3.5-flash-lite`. The key is never in these files: every command below reads it from
`$GEMINI_API_KEY`. The format they show is written up in `docs/ai.md#observed-format`.

Every request uses:

```sh
curl -sS --max-time 60 -H "x-goog-api-key: $GEMINI_API_KEY" -H "Content-Type: application/json" \
  https://generativelanguage.googleapis.com/v1beta/interactions -d @body.json
```

Only harmless prompts were sent (the free tier may be used by Google to improve its products).

## reply.json

Plain, non-streamed reply. Pretty-printed with `python3 -m json.tool` (the bytes arrived minified).
HTTP status not captured with `-w`; the body is a completed interaction.

Body:

```json
{"model":"gemini-3.5-flash-lite","input":"Say hello in five words.","system_instruction":"You are Aash, a small pixel buddy. Be brief.","store":false,"generation_config":{"thinking_level":"minimal","max_output_tokens":1024}}
```

## stream.txt

Raw SSE bytes, saved unedited with `--no-buffer > stream.txt`. HTTP status not captured.

Body: the same as `reply.json` plus `"stream":true`, sent to `…/interactions?alt=sse`:

```sh
curl -sS --no-buffer --max-time 60 -H "x-goog-api-key: $GEMINI_API_KEY" -H "Content-Type: application/json" \
  "https://generativelanguage.googleapis.com/v1beta/interactions?alt=sse" -d @body.json > stream.txt
```

## json-reply.json

Reply constrained by `response_format`, using the T22 schema from `docs/reminders.md`.
Pretty-printed with `python3 -m json.tool`. HTTP status not captured.

Body:

```json
{"model":"gemini-3.5-flash-lite","input":"Remind me to call mum tomorrow at 7pm. Today is Sunday 2026-10-18, 10:00.","system_instruction":"You are Aash, a small pixel buddy. Be brief.","store":false,"generation_config":{"thinking_level":"minimal","max_output_tokens":1024},"response_format":{"type":"text","mime_type":"application/json","schema":{"type":"object","properties":{"isReminder":{"type":"boolean"},"title":{"type":"string"},"due":{"type":"string","description":"ISO 8601 local date-time, e.g. 2026-10-18T18:00"}},"required":["isReminder"]}}}
```

## two-turns.json

Two-turn conversation sent as an array of steps in `input`. Pretty-printed with
`python3 -m json.tool`. HTTP status 200.

Shape tried first, as the card specifies: step objects with `type` and `content`. **Accepted**, so
the `{"role":…,"content":…}` fallback was not needed. The reply was
`"Your name is Sam!"`.

Body:

```json
{"model":"gemini-3.5-flash-lite","input":[{"type":"user_input","content":[{"type":"text","text":"My name is Sam."}]},{"type":"model_output","content":[{"type":"text","text":"Nice to meet you, Sam!"}]},{"type":"user_input","content":[{"type":"text","text":"What is my name?"}]}],"system_instruction":"You are Aash, a small pixel buddy. Be brief.","store":false,"generation_config":{"thinking_level":"minimal","max_output_tokens":1024}}
```

## bad-key.json

The plain request from `reply.json`, sent with the literal fake key `not-a-real-key` in place of
`$GEMINI_API_KEY`:

```sh
curl -sS --max-time 60 -w '\n%{http_code}\n' -H "x-goog-api-key: not-a-real-key" -H "Content-Type: application/json" \
  https://generativelanguage.googleapis.com/v1beta/interactions -d @body.json
```

HTTP status **400**. The body is a JSON **array** holding one object, so the message is at
`[0].error.message` and the status string at `[0].error.status` (`INVALID_ARGUMENT`). The
`error.details[].reason` is `API_KEY_INVALID`. Pretty-printed with `python3 -m json.tool`.
