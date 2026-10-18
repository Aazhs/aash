# Chat and AI

The buddy's chat talks to the Gemini API through a small provider protocol, so a second provider
(Claude Code, Phase 5) plugs in without touching the UI. Nothing runs on the Mac except a network
request, so chat costs almost no memory or CPU.

## Provider design (AashAI)

```swift
/// One message in a conversation.
public struct ChatMessage: Equatable, Sendable {
    public enum Role: String, Sendable { case user, model }
    public var role: Role
    public var text: String
}

/// Something that can answer a conversation.
public protocol ChatProvider: Sendable {
    /// Streams the reply as text chunks. Cancelling the stream cancels the request.
    func stream(_ messages: [ChatMessage], system: String) -> AsyncThrowingStream<String, Error>
    /// One non-streamed reply whose text is JSON matching `schema` (a JSON Schema document).
    func json(_ prompt: String, system: String, schema: Data) async throws -> Data
}

/// What can go wrong, in terms the UI can explain.
public enum ChatError: Error, Equatable {
    case noKey                         // no API key saved
    case badKey                        // 400/401/403 that means the key was rejected
    case quota(resetsAt: Date?)        // 429
    case offline                       // no network
    case timedOut
    case server(status: Int, message: String)
    case badResponse(String)           // couldn't parse what came back
}
```

T15 fixes the exact signatures; this is the shape.

## Gemini

### What's verified (Google's docs, read 17–18 Oct 2026)

| Thing | Value | Source |
|---|---|---|
| Model | `gemini-3.5-flash-lite`: stable, 1,048,576 tokens in, 65,536 out; structured output, function calling and thinking supported | [model page](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite) |
| Price | Free tier: free. Paid: $0.30 in, $2.50 out per 1M tokens | [pricing](https://ai.google.dev/gemini-api/docs/pricing) |
| Free tier data | Google may use free-tier content to improve its products | [pricing](https://ai.google.dev/gemini-api/docs/pricing) |
| Limits | Per project, shown in AI Studio; daily limits reset at midnight Pacific time | [rate limits](https://ai.google.dev/gemini-api/docs/rate-limits) |
| Endpoint | `POST https://generativelanguage.googleapis.com/v1beta/interactions` | [text generation](https://ai.google.dev/gemini-api/docs/text-generation) |
| Auth | Header `x-goog-api-key: <key>` | same |
| Body | `model`, `input` (a string, or an array of steps), `system_instruction` (a string) | same |
| History | Server-side by default (`previous_interaction_id`). We send `"store": false` and resend the short history ourselves, so nothing is kept on Google's side between chats | same |
| Streaming | Same endpoint with `?alt=sse` and `"stream": true`. Text arrives in events whose `event_type` is `"step.delta"` and whose `delta.type` is `"text"`, in `delta.text` | same |
| Structured output | Top-level `"response_format": {"type": "text", "mime_type": "application/json", "schema": {…}}`; the reply text is the JSON | [structured output](https://ai.google.dev/gemini-api/docs/structured-output) |
| Thinking | `"generation_config": {"thinking_level": "minimal"}`; minimal is already the default for 3.5 Flash-Lite. Thinking tokens count as output and against `max_output_tokens` | [thinking](https://ai.google.dev/gemini-api/docs/thinking) |

### What T14 records

Google's pages show SDK code, not raw bytes. Before any client code is written, T14 makes real
requests with `curl` and saves the exact responses in `Tests/Fixtures/gemini/`:

- a plain reply (the response JSON; its text is in the steps, not an `output_text` field)
- a streamed reply (the raw SSE frames: `event:` and `data:` lines, and how the stream ends)
- a JSON reply with `response_format`
- a two-turn conversation with `"store": false` (the exact shape of history steps in `input`)
- an error with a bad key (status and body)

T14 writes what it found under "Observed format" below. T15 builds the client and its tests from
those fixtures.

### Observed format

Recorded 18 Oct 2026 with `gemini-3.5-flash-lite`. The fixtures and their curl commands are in
`Tests/Fixtures/gemini/` (see its `README.md`). There is no `output_text` field in any response.

| Fixture | What it shows |
|---|---|
| `reply.json` | Reply text at `steps[1].content[0].text`, where `steps[1].type == "model_output"` and `content[0].type == "text"`. `status` is `"completed"`. `steps[0]` is a thinking step with `type == "thought"` (it has a `signature`, no text), so the reply is the step whose `type` is `model_output`, not a fixed index. |
| `stream.txt` | Each frame has an `event:` line and a `data:` line. `event_type` values in order: `interaction.created`, `interaction.status_update`, `step.start` (thought), `step.delta` (`thought_signature`), `step.stop`, `step.start` (model_output), `step.delta` (text), `step.delta` (text), `step.stop`, `interaction.completed`, `done`. Text chunks are `data.delta.text` where `data.delta.type == "text"`. The stream ends with an `event: done` frame whose data is `[DONE]`, after `interaction.completed`. |
| `json-reply.json` | The JSON string is at `steps[1].content[0].text` (the `model_output` step). It parses to `{"isReminder": true, "due": "2026-10-19T19:00", "title": "Call mum"}`, which matches the T22 schema (`isReminder` is a boolean, the other fields are strings). |
| `two-turns.json` | The array-of-steps shape works: `input` is `[{"type":"user_input","content":[{"type":"text","text":…}]}, {"type":"model_output","content":[{"type":"text","text":…}]}, {"type":"user_input","content":[…]}]`, with `"store":false`. HTTP 200; the reply was "Your name is Sam!". The `role`/`content` fallback was not needed. |
| `bad-key.json` | HTTP **400**. The body is a JSON array with one object: message at `[0].error.message` ("API key not valid. Please pass a valid API key."), status at `[0].error.status` (`INVALID_ARGUMENT`), reason at `[0].error.details[0].reason` (`API_KEY_INVALID`). Map this to `badKey`. |

Fixture file names: `reply.json`, `stream.txt`, `json-reply.json`, `two-turns.json`, `bad-key.json`.

Notes for the client: a non-streamed reply's text is found by picking the `model_output` step, not
by index. The reply step types seen so far are `thought` and `model_output`.

### Requests the app makes

| When | Request |
|---|---|
| Chat message | streamed; history = this popover session only; `max_output_tokens` 1024 |
| Clipboard action | streamed; one user message: the instruction plus the clipboard text (cut to 20,000 characters) |
| Reminder fallback (T22) | `json` with the reminder schema in `docs/reminders.md` |

No request is ever made in the background.

### Errors the user sees

| Error | Line shown in the popover |
|---|---|
| `noKey` | "Add your free Gemini key in Settings to chat." with a Settings button |
| `badKey` | "Gemini didn't accept the key. Check it in Settings." |
| `quota` | "Free Gemini limit reached for today. It resets at 12:30 PM." (the reset time in local time) |
| `offline` | "You're offline. Chat needs the internet; everything else still works." |
| `timedOut` | "Gemini took too long. Try again?" |
| `server`, `badResponse` | "Something went wrong talking to Gemini." (details in the log) |

### The buddy's voice

System instruction for chat (keep it short; it's sent with every request):

> You are Aash, a small pixel buddy who lives in the user's macOS menu bar. Be warm and brief:
> at most four short sentences unless asked for more. Plain text only: no headings, tables or
> markdown. If asked to do something on the Mac, say what the user can do instead.

Clipboard actions use their own one-line instructions: "Summarise this in three short bullet
points.", "Rewrite this to be clear and friendly; keep the meaning.", "Explain this simply."

## Keychain

The API key lives in the login Keychain as a generic password: service `me.aarshj.aash`, account
`gemini`. The settings window writes it; `GeminiProvider` gets it as a string from the app (the
library never reads the Keychain by itself). Tests never touch the real item: they use the service
`me.aarshj.aash.tests` and delete what they create.

## Claude Code ("Ask Claude", Phase 5)

An optional second provider for hard questions, using the Claude Code CLI you already have and your
Claude plan. Rules:

- **Personal use only.** It runs your own `claude` with your own login. A build shared with others
  should use an API key provider instead.
- **Lean start.** `--bare` would skip loading hooks, plugins and MCP servers, but bare mode never
  uses a subscription login. So instead, run in an empty temporary folder with
  `claude -p --model haiku --tools "" --strict-mcp-config --disable-slash-commands
  --no-session-persistence --system-prompt "<the voice above>" --output-format stream-json
  --verbose --include-partial-messages "<question>"`.
- **Streaming:** text deltas are lines whose `type` is `stream_event` with
  `event.delta.type == "text_delta"`; the text is `event.delta.text`. The last line is a `result`.
- **Cost check first.** T24 measures start-up time and memory with `/usr/bin/time -l` before wiring
  it in. If a reply takes more than about 5 s to start, it stays an explicit button, never the default.

Flags are from the [CLI reference](https://code.claude.com/docs/en/cli-reference) and
[headless docs](https://code.claude.com/docs/en/headless), read 18 Oct 2026.
