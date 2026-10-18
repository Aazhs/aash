# T15 · Gemini client

Phase 3 · Target: AashAI · Risk: medium · Detail: full

## Goal

`GeminiProvider` implements `ChatProvider` against the Interactions API: streamed chat, JSON
replies, and failures mapped to `ChatError`. Tests replay T14's fixtures and synthetic responses
through a stubbed `URLProtocol`, so they never touch the network.

## Read first

- `docs/ai.md`: provider design, "What's verified", **"Observed format" (written by T14: where it
  disagrees with this card, the observed format and the fixtures win; say so in your report)**
- `docs/patterns.md#streaming`, `#fixtures`, `#tests`
- `Sources/AashAI/ChatProvider.swift`, `ServerSentEvents.swift` (T31)
- `Tests/Fixtures/gemini/*` and its `README.md` (T14)

## Files

- create `Sources/AashAI/GeminiWire.swift`: request building, response decoding, error mapping
- create `Sources/AashAI/GeminiProvider.swift`
- create `Tests/AashAITests/StubURLProtocol.swift`
- create `Tests/AashAITests/GeminiProviderTests.swift`
- `git rm Sources/AashAI/AashAI.swift Tests/AashAITests/AashAITests.swift` (placeholders)
- edit `docs/architecture.md`: nothing unless a name differs from the table there

## Interfaces

```swift
// GeminiProvider.swift
import Foundation

/// Chats with Gemini through the Interactions API.
public struct GeminiProvider: ChatProvider {
    /// `apiKey` nil or empty makes every call fail with `.noKey` before any request.
    /// `baseURL` and `now` exist for tests.
    public init(apiKey: String?, model: String = "gemini-3.5-flash-lite",
                session: URLSession = .shared,
                baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!,
                now: @escaping @Sendable () -> Date = { Date() })
    public func stream(_ messages: [ChatMessage], system: String) -> AsyncThrowingStream<String, Error>
    public func json(_ prompt: String, system: String, schema: Data) async throws -> Data
}

// GeminiWire.swift: internal
enum GeminiWire {
    /// The request body for a chat turn. `schema` non-nil adds `response_format`.
    static func body(model: String, messages: [ChatMessage], system: String, stream: Bool, schema: Data?) throws -> Data
    /// The reply text in a non-streamed response (all `model_output` text parts, joined).
    static func replyText(_ data: Data) throws -> String
    /// The text chunk in one SSE `data:` payload; nil for events without text; throws on an `error` event.
    static func chunk(_ event: ServerSentEvent) throws -> String?
    /// Maps a failed HTTP response to a `ChatError`.
    static func error(status: Int, body: Data, now: Date) -> ChatError
    /// Midnight Pacific after `now`: when the free tier's daily limit resets.
    static func nextPacificMidnight(after now: Date) -> Date
}
```

(The `!` on the default `baseURL` literal is the one allowed force unwrap: a constant literal URL.
Add a `// constant literal` comment. Everything else must avoid `!`.)

## Steps

1. `GeminiWire.body`: a JSON object with keys `model`, `input`, `system_instruction` (a string),
   `store` = false, `generation_config` = `{"thinking_level": "minimal", "max_output_tokens": 1024}`.
   `input` is an array of steps in the shape of `Tests/Fixtures/gemini/two-turns.json`. The expected
   shape from the docs is `{"type":"user_input","content":[{"type":"text","text":…}]}` for
   `.user` and `{"type":"model_output","content":[…]}` for `.model`. `stream` true adds
   `"stream": true`. `schema` non-nil adds
   `"response_format": {"type":"text","mime_type":"application/json","schema": <the schema JSON>}`.
   Build with `JSONSerialization` (the schema arrives as `Data`, so parse it first; a parse failure
   throws `ChatError.badResponse("bad schema")`). Use `.sortedKeys` so tests can compare bodies.
2. `GeminiWire.replyText`: decode with `JSONSerialization`; walk `steps`, keep items whose `type` is
   `model_output`, then their `content` items whose `type` is `text`; join the `text` strings. No
   text found → throw `ChatError.badResponse("no text in reply")`. Use the paths T14 recorded.
3. `GeminiWire.chunk`: `event.data == "[DONE]"` → nil. Otherwise parse `event.data` as a JSON
   object; `event_type == "step.delta"` and `delta.type == "text"` → `delta.text`; `event_type ==
   "error"` → throw `ChatError.server(status: 0, message: <error.message or "stream error">)`;
   anything else → nil. Decide by `event_type` inside the JSON, not by the `event:` name. Invalid
   JSON → nil (log nothing).
4. `GeminiWire.error(status:body:now:)`:
   - 429 → `.quota(resetsAt: nextPacificMidnight(after: now))`
   - 400, 401, 403 → `.badKey` when the body text contains `API key not valid`, `API_KEY_INVALID` or
     `PERMISSION_DENIED`; for any other 400 → `.server(status:, message:)`; 401/403 → `.badKey`
   - 408 → `.timedOut`
   - everything else → `.server(status:, message:)` where `message` is `error.message` from the
     JSON body, else the first 200 characters of the body, else `"HTTP \(status)"`
   Check the bad-key rule against `bad-key.json`; if it contains neither phrase, change the phrases
   to what it does contain and say so in your report.
5. `nextPacificMidnight`: `Calendar(identifier: .gregorian)` with `timeZone` =
   `TimeZone(identifier: "America/Los_Angeles")`; `calendar.nextDate(after: now, matching:
   DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime)`; fall back to
   `now + 86400` if nil.
6. `GeminiProvider.stream`:
   1. Capture `apiKey`, `model`, `session`, `baseURL`, `now` into locals (the closure must not
      capture `self` strictly needed; the struct is `Sendable`).
   2. Return `AsyncThrowingStream { continuation in … }` following `docs/patterns.md#streaming`:
      a `Task` that does the work and `continuation.onTermination = { _ in task.cancel() }`.
   3. In the task: no key → `continuation.finish(throwing: ChatError.noKey)` and return.
   4. Build the `URLRequest`: URL = `baseURL` with query `alt=sse`; POST; headers
      `Content-Type: application/json` and `x-goog-api-key: <key>`; `timeoutInterval = 30`.
   5. `let (bytes, response) = try await session.bytes(for: request)`. Not an `HTTPURLResponse` →
      `.badResponse("no response")`. Status outside 200..<300 → read at most 4,096 bytes from
      `bytes`, then finish with `GeminiWire.error(status:body:now: now())`.
   6. Otherwise `var parser = ServerSentEventParser()`; `for try await line in bytes.lines`: if
      `parser.feed(line)` returns an event, `if let text = try GeminiWire.chunk(event) { continuation.yield(text) }`.
      Call `try Task.checkCancellation()` each line. After the loop, `continuation.finish()`.
   7. Catch: `CancellationError` or `URLError.cancelled` → `finish()` quietly. Other errors →
      `finish(throwing: Self.map(error))` where `map` is a private static that turns `ChatError`
      into itself, `URLError.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed` →
      `.offline`, `URLError.timedOut` → `.timedOut`, anything else → `.badResponse(error.localizedDescription)`.
7. `GeminiProvider.json`: same request (no `alt=sse`, `stream` false, `schema` set, `messages` =
   `[ChatMessage(role: .user, text: prompt)]`); `try await session.data(for:)`; non-2xx →
   `GeminiWire.error`; else `Data(try GeminiWire.replyText(data).utf8)`. Same error mapping. No key →
   throw `.noKey`.
8. Never log the key, the prompt or the reply (`patterns.md#logging`). Logging an HTTP status at
   `.error` is fine: `Logger(subsystem: "me.aarshj.aash", category: "Gemini")`, in
   `GeminiProvider.swift`, `privacy: .public` on the number.
9. Tests (below). `StubURLProtocol` rules:
   - `final class StubURLProtocol: URLProtocol` with a static, lock-protected dictionary from
     **host** to `Stub` (`status: Int`, `chunks: [Data]`, `hold: Bool`, `error: URLError?`). Tests
     use a unique host per test (`"stub-\(UUID().uuidString.lowercased()).test"`) so parallel tests
     don't collide.
   - `static func session(for stub: Stub) -> (URLSession, URL)` registers the stub, returns an
     ephemeral session with `protocolClasses = [StubURLProtocol.self]` and the base URL
     `https://<host>/v1beta/interactions`.
   - `startLoading` sends the response with the stub's status, then each chunk, then (unless
     `hold`) `urlProtocolDidFinishLoading`; if `error` is set it calls `didFailWithError` instead.
     `stopLoading` sets a lock-protected `stopped` flag for that host.
   - Use `NSLock` plus `@unchecked Sendable` only inside this test helper, with a comment saying why.
   - A `static func requests(for host:) -> [URLRequest]` records what was sent (the body arrives via
     `httpBodyStream`; read it fully in `startLoading`).

## Rules

- Library: Foundation and os only. Value types, `Sendable`. `async/await`, no `DispatchQueue`.
- One main type per file; keep both source files under about 250 lines.
- `AsyncThrowingStream` cancellation must cancel the URL task (CLAUDE.md rule 6, `patterns.md#streaming`).
- No third-party code. No real network in tests: every test uses `StubURLProtocol`.
- Tests: no `Date()`, build dates from components with a fixed time zone (`patterns.md#tests`).

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] `grep -rn "print(" Sources/AashAI` finds nothing
- [ ] Tests (suite `GeminiProviderTests`, one `@Test` each):
  - `streamYieldsTextChunksInOrder`: stub body (inline string) `event: step.delta\ndata: {"index":0,"delta":{"type":"text","text":"Hel"},"event_type":"step.delta"}\n\nevent: step.delta\ndata: {"index":0,"delta":{"type":"text","text":"lo"},"event_type":"step.delta"}\n\nevent: done\ndata: [DONE]\n\n` → chunks `["Hel", "lo"]`
  - `streamIgnoresNonTextEvents`: add `event: interaction.created`, `step.start`, `step.stop` and
    `interaction.completed` frames (JSON with matching `event_type`) around one text delta → one chunk
  - `streamFixtureYieldsTheRecordedText`: stub body = `Tests/Fixtures/gemini/stream.txt`; the
    chunks, joined, equal the text copied by hand from that file (read the file, write the expected
    string in the test)
  - `replyFixtureYieldsTheRecordedText`: `json(…)` against `reply.json` returns `Data` whose UTF-8
    string equals the reply text in that file (only if `json` accepts a plain reply; otherwise
    test `GeminiWire.replyText(_:)` directly with the fixture)
  - `jsonFixtureReturnsParsableJSON`: stub body = `json-reply.json`; `json(…)` returns data that
    `JSONSerialization` parses into a dictionary with `isReminder == true`
  - `badKeyFixtureMapsToBadKey`: stub status 400 (or the status recorded in `README.md`), body =
    `bad-key.json` → the stream throws `ChatError.badKey`
  - `status429MapsToQuotaWithPacificMidnight`: `GeminiWire.error(status: 429, body: Data(), now:)` with
    now = 2026-10-18 10:00 `Asia/Kolkata` → `.quota(resetsAt: 2026-10-18 07:00 UTC)`; and now =
    2026-11-02 12:00 UTC → `.quota(resetsAt: 2026-11-03 08:00 UTC)`
  - `status500MapsToServer`: body `{"error":{"message":"boom"}}` → `.server(status: 500, message: "boom")`
  - `noKeyFailsWithoutARequest`: `apiKey: nil` and `apiKey: ""` → `.noKey`, and
    `StubURLProtocol.requests(for:)` is empty
  - `offlineAndTimeoutMapToChatErrors`: stub error `URLError(.notConnectedToInternet)` → `.offline`;
    `URLError(.timedOut)` → `.timedOut`
  - `requestCarriesKeyAndStoreFalse`: after a call, the recorded request has header
    `x-goog-api-key` equal to the test key `"test-key"`, query `alt=sse`, method POST; its body
    parses to JSON with `store == false`, `generation_config.thinking_level == "minimal"`,
    `generation_config.max_output_tokens == 1024`, `stream == true`, `system_instruction` equal to
    the system string passed
  - `twoTurnBodyMatchesTheFixtureShape`: `GeminiWire.body(...)` for [user "My name is Sam.", model
    "Nice to meet you, Sam!", user "What is my name?"] has an `input` array equal (as parsed JSON) to
    the `input` of `two-turns.json`
  - `jsonRequestAddsResponseFormat`: body for `json(...)` has `response_format.mime_type ==
    "application/json"` and no `stream` key
  - `cancellingTheStreamCancelsTheRequest`: stub with `hold: true` and one chunk; start a task
    iterating the stream, wait for the first chunk, cancel the task; within 2 s the stub's `stopped`
    flag is true (poll with `Task.sleep(for: .milliseconds(50))` up to 40 times; polling is fine in a test)

## Out of scope

- Retries, backoff, caching, token counting, tool calls.
- Reading the Keychain (the app passes the key in) and any UI.
- A provider-picking layer: Phase 5.

## Notes

- `URLSession.AsyncBytes.lines` drops empty lines; that's why `ServerSentEventParser` emits on each
  `data:` line (T31).
- The docs mention `event: done` / `data: [DONE]` at the end; the loop must also end cleanly if the
  connection just closes.
- Thinking tokens count against `max_output_tokens`; `minimal` keeps that small.
- If `stream.txt` shows `event_type` names different from `step.delta`, follow the fixture and tell
  the reviewer.
