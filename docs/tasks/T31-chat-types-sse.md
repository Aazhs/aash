# T31 · Chat types and SSE parser

Phase 3 · Target: AashAI · Risk: low · Detail: full

## Goal

`AashAI` has the provider-neutral chat types (`ChatMessage`, `ChatProvider`, `ChatError`) and a
parser that turns Server-Sent Events lines into events. T15 builds the Gemini client on them.

## Read first

- `docs/ai.md#provider-design-aashai`: the shapes
- `docs/patterns.md#tests`
- `docs/architecture.md#targets`: AashAI may import Foundation, Security and os only

## Files

- create `Sources/AashAI/ChatMessage.swift`
- create `Sources/AashAI/ChatProvider.swift`: the protocol and `ChatError` (two small types, one file)
- create `Sources/AashAI/ServerSentEvents.swift`
- create `Tests/AashAITests/ServerSentEventsTests.swift`
- `git rm` is **not** used here: leave `AashAI.swift` and its test; T15 deletes them.

## Interfaces

```swift
// ChatMessage.swift
/// One message in a conversation.
public struct ChatMessage: Equatable, Sendable {
    public enum Role: String, Sendable { case user, model }
    public var role: Role
    public var text: String
    public init(role: Role, text: String)
}

// ChatProvider.swift
/// Something that can answer a conversation.
public protocol ChatProvider: Sendable {
    /// Streams the reply as text chunks. Cancelling the stream cancels the request.
    func stream(_ messages: [ChatMessage], system: String) -> AsyncThrowingStream<String, Error>
    /// One non-streamed reply whose text is JSON matching `schema` (a JSON Schema document).
    func json(_ prompt: String, system: String, schema: Data) async throws -> Data
}

/// What can go wrong, in terms the UI can explain.
public enum ChatError: Error, Equatable, Sendable {
    case noKey
    case badKey
    case quota(resetsAt: Date?)
    case offline
    case timedOut
    case server(status: Int, message: String)
    case badResponse(String)
}

// ServerSentEvents.swift
/// One server-sent event: the `event:` name (if the frame had one) and its `data:` payload.
public struct ServerSentEvent: Equatable, Sendable {
    public var name: String?
    public var data: String
    public init(name: String?, data: String)
}

/// Turns SSE lines into events. Feed it one line at a time.
public struct ServerSentEventParser: Sendable {
    public init()
    /// Returns the event completed by `line`, or nil.
    public mutating func feed(_ line: String) -> ServerSentEvent?
}
```

## Steps

1. Create the three type files exactly as in Interfaces (copy the doc comments).
2. `ServerSentEventParser` rules. It keeps `pendingName: String?`.
   1. A line starting `event:` sets `pendingName` to the rest of the line with leading spaces
      removed. Returns nil.
   2. A line starting `data:` returns `ServerSentEvent(name: pendingName, data: <rest, leading
      single space removed>)` and clears `pendingName`. **Each `data:` line is one complete event.**
      Don't wait for a blank line: `URLSession.AsyncBytes.lines` drops empty lines, so a blank
      line never arrives.
   3. Any other line (blank, `:` comment, `id:`, `retry:`) returns nil and changes nothing.
3. Write the tests below.

## Rules

- Value types only, all `Sendable`. No `print`. No force unwraps (CLAUDE.md style).
- Library target: no AppKit, no SwiftUI.
- Every public declaration has a one-line doc comment.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] Tests in `ServerSentEventsTests.swift` (one `@Test` each, suite `ServerSentEventsTests`):
  - `dataLineAloneIsAnEvent`: feed `data: {"a":1}` → `ServerSentEvent(name: nil, data: "{\"a\":1}")`
  - `eventNameAttachesToNextData`: feed `event: step.delta` → nil, then `data: x` → `(name: "step.delta", data: "x")`
  - `nameIsClearedAfterUse`: after the previous case, feed `data: y` → `(name: nil, data: "y")`
  - `blankAndCommentLinesAreIgnored`: feed `""` and `: keep-alive` → nil both
  - `doneSentinelIsPassedThrough`: feed `event: done`, then `data: [DONE]` → `(name: "done", data: "[DONE]")`
  - `noSpaceAfterColonStillWorks`: feed `data:abc` → data `"abc"`
  - `chatErrorsCompare`: `ChatError.quota(resetsAt: nil) == .quota(resetsAt: nil)` and
    `ChatError.server(status: 500, message: "x") != .server(status: 500, message: "y")`

## Out of scope

- The Gemini client, URL requests, JSON decoding: T15.
- Deleting the placeholder `AashAI.swift`: T15.

## Notes

- Why per-line events: see `docs/decisions.md` (18 Oct 2026, SSE).
- Gemini's frames are `event: <type>` then one `data:` line then a blank line (documented, to be
  confirmed by T14's `stream.txt`).
