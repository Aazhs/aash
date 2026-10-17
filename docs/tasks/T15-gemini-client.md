# T15 · Gemini client

Phase 3 · Target: AashAI · Risk: medium · Detail: outline

## Goal

`GeminiProvider` implements `ChatProvider` against the Interactions API: streamed chat, JSON
replies, and errors mapped to `ChatError`. Tests replay T14's fixtures through a stubbed
`URLProtocol`, so they never touch the network.

## Read first

- `docs/ai.md`: provider design, verified facts, observed format (from T14), errors
- `docs/patterns.md#streaming`, `#fixtures`, `#tests`
- `Tests/Fixtures/gemini/*`

## Files (expected)

- create `Sources/AashAI/ChatMessage.swift`, `ChatProvider.swift`, `ChatError.swift`
- create `Sources/AashAI/ServerSentEvents.swift` (bytes or lines → events)
- create `Sources/AashAI/GeminiProvider.swift`
- create `Tests/AashAITests/GeminiProviderTests.swift`, `ServerSentEventsTests.swift`, `StubURLProtocol.swift`
- delete `Sources/AashAI/AashAI.swift` and its placeholder test

## Sketch

```swift
public struct GeminiProvider: ChatProvider {
    public init(apiKey: String?, model: String = "gemini-3.5-flash-lite", session: URLSession = .shared)
}
```

- `apiKey == nil` → every call fails with `.noKey` without a request.
- Requests: `store: false`, `system_instruction`, `generation_config.thinking_level: "minimal"`,
  `max_output_tokens: 1024`.
- HTTP 429 → `.quota(resetsAt:)` with the next midnight in `America/Los_Angeles`.
- `URLError.notConnectedToInternet` → `.offline`; `.timedOut` → `.timedOut`.

## Done when (to be detailed by /plan-phase 3)

- [ ] Tests: stream fixture → the exact text chunks; JSON fixture → the JSON data; bad-key
  fixture → `.badKey`; synthetic 429 → `.quota` with the right reset date; cancelling the stream
  cancels the task
- [ ] `./scripts/check.sh` prints `CHECK PASS`
