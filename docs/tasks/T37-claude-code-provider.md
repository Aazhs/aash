# T37 · Claude Code provider

Phase 5 · Target: AashAI · Risk: medium · Detail: full

## Goal

`ClaudeCodeProvider` is a `ChatProvider` that answers one question by running the user's own
`claude -p` and streaming its `stream-json` output as text chunks. Cancelling the stream kills the
process. It also finds `claude` on disk. Pure library code with tests; T24 adds the button.

## Read first

- `docs/ai.md#claude-code-ask-claude-phase-5`: the flags and the measured cost
- `Tests/Fixtures/claude/README.md`: what the recorded lines look like
- `Sources/AashAI/GeminiProvider.swift`: the stream shape to copy (`Task`, `withTaskCancellationHandler`, `onTermination`)
- `docs/patterns.md#tests` and `#fixtures`

## Files

- create `Sources/AashAI/ClaudeCodeProvider.swift`
- edit `Sources/AashAI/ChatPrompts.swift`: three lines for the Ask Claude button (below)
- create `Tests/AashAITests/ClaudeCodeProviderTests.swift`

The fixtures `Tests/Fixtures/claude/stream.jsonl` and `bad-model.jsonl` already exist. Don't
re-record them, and don't run `claude` yourself: every call uses the user's Claude plan.

## Interfaces

```swift
// ClaudeCodeProvider.swift
import Foundation

/// Answers one question with the Claude Code CLI (`claude -p`), using the user's own Claude login.
public struct ClaudeCodeProvider: ChatProvider {
    /// What can go wrong when asking Claude.
    public enum Failure: Error, Equatable, Sendable {
        /// `claude` couldn't be started, or its working folder couldn't be made.
        case launch
        /// Claude ended with an error; `message` is its text, for the log only.
        case claude(message: String)
        /// The output ended without a result line, or there was no question.
        case noResult
        /// This provider has no JSON replies.
        case unsupported
    }

    /// One line of `--output-format stream-json` output, reduced to what the app uses.
    public enum Line: Equatable, Sendable {
        /// A text chunk of the reply.
        case text(String)
        /// The last line: whether it failed, and its `result` text.
        case result(isError: Bool, message: String)
        /// Anything else, including lines that aren't JSON.
        case other
    }

    /// The folder `claude` runs in: `aash-claude` inside the temporary directory, empty on purpose.
    public static var defaultWorkingDirectory: URL { get }

    /// `executable` is the `claude` binary; `model` is passed to `--model`.
    public init(executable: URL, model: String = "haiku",
                workingDirectory: URL = ClaudeCodeProvider.defaultWorkingDirectory)

    /// Where `claude` is usually installed, most likely first.
    public static func candidates(home: URL) -> [URL]

    /// The first of `candidates` that is an executable file, or nil.
    public static func locate(in candidates: [URL], fileManager: FileManager = .default) -> URL?

    /// The full argument list for one question.
    public static func arguments(question: String, system: String, model: String) -> [String]

    /// Reads one output line.
    public static func parse(_ line: String) -> Line

    /// Streams the reply to the last user message in `messages`. Cancelling the stream kills `claude`.
    public func stream(_ messages: [ChatMessage], system: String) -> AsyncThrowingStream<String, Error>

    /// Always throws `Failure.unsupported`.
    public func json(_ prompt: String, system: String, schema: Data) async throws -> Data
}
```

```swift
// ChatPrompts.swift, added at the end of the enum
/// The button title for asking Claude.
public static let askClaudeTitle = "Ask Claude"
/// Shown when Ask Claude is clicked with an empty text field.
public static let askClaudeEmpty = "Type a question first, then click Ask Claude."
/// Shown when Claude couldn't answer.
public static let claudeFailed = "Claude couldn't answer. Check that claude works in Terminal."
```

## Steps

1. `defaultWorkingDirectory`: `FileManager.default.temporaryDirectory.appendingPathComponent("aash-claude", isDirectory: true)`.
2. `candidates(home:)` returns exactly, in this order:
   `home/.local/bin/claude`, `/opt/homebrew/bin/claude`, `/usr/local/bin/claude`.
   `locate(in:fileManager:)` returns the first URL whose path passes
   `fileManager.isExecutableFile(atPath:)`.
3. `arguments(question:system:model:)` returns exactly:
   ```swift
   ["-p", "--model", model, "--tools", "", "--strict-mcp-config", "--disable-slash-commands",
    "--no-session-persistence", "--system-prompt", system, "--output-format", "stream-json",
    "--verbose", "--include-partial-messages", "--", question]
   ```
   The `--` stops a question that starts with `-` from being read as a flag. It was checked
   with Claude Code 2.1.302: `-- "-5 plus 3?"` answered `-2`.
4. `parse(_:)`: decode the line with `JSONSerialization` as a `[String: Any]`. If it doesn't
   decode, return `.other`.
   - `type == "stream_event"`, `event.type == "content_block_delta"`, `event.delta.type ==
     "text_delta"` and `event.delta.text` is a non-empty string: `.text(that string)`.
   - `type == "result"`: `.result(isError: is_error as? Bool ?? true, message: result as? String ?? "")`.
   - Anything else: `.other`.
5. `stream(_:system:)`. Copy the shape of `GeminiProvider.stream`: an `AsyncThrowingStream`
   whose body starts one `Task` and sets `continuation.onTermination = { _ in task.cancel() }`.
   Inside the task:
   1. `question` is `messages.last(where: { $0.role == .user })?.text`. If it's nil, finish
      throwing `Failure.noResult`.
   2. Create `workingDirectory` with `withIntermediateDirectories: true`. If that fails, finish
      throwing `Failure.launch`.
   3. Make a `Process`: set `executableURL`, `arguments` from step 3, and
      `currentDirectoryURL = workingDirectory`. Set `standardOutput` to a new `Pipe()`, and set
      `standardError` and `standardInput` to `FileHandle.nullDevice`. If `try process.run()`
      throws, finish throwing `Failure.launch`.
   4. `let pid = process.processIdentifier`. Read the lines inside `withTaskCancellationHandler`,
      whose `onCancel` is `kill(pid, SIGTERM)`. Return the last `.result` from the operation,
      instead of mutating a captured variable:
      ```swift
      let last = try await withTaskCancellationHandler {
          var last: Line?
          for try await line in pipe.fileHandleForReading.bytes.lines {
              try Task.checkCancellation()
              switch Self.parse(line) {
              case .text(let text): continuation.yield(text)
              case .result(let isError, let message): last = .result(isError: isError, message: message)
              case .other: break
              }
          }
          return last
      } onCancel: {
          kill(pid, SIGTERM)
      }
      ```
   5. After the loop: if `Task.isCancelled`, `continuation.finish()`. Otherwise
      `.result(isError: false, _)` → `finish()`, `.result(isError: true, let message)` → finish
      throwing `Failure.claude(message: message)`, nil → finish throwing `Failure.noResult`.
   6. `catch is CancellationError` → `continuation.finish()`. Any other error → finish throwing it.
6. `json`: `throw Failure.unsupported`.
7. Add the three `ChatPrompts` constants.

## Rules

- Foundation only: `Process`, `Pipe`, `FileHandle.bytes` and `kill` all come with it. No
  `@unchecked Sendable`, no stored `Process`, no `waitUntilExit()` (it blocks a thread).
- Only the `pid`, an `Int32`, crosses into the `@Sendable` `onCancel` closure. A planning
  prototype of exactly this shape compiled in Swift 6 mode with no warnings. It reached EOF when
  the child exited, and `kill` stopped a `sleep 30` child within 0.5 s.
- No logging in this file. T24 logs failures in the app (CLAUDE.md: never log chat content).
- One main type per file. The nested `Failure` and `Line` stay inside it.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] Tests in `ClaudeCodeProviderTests.swift`, one `@Test` each. Load fixtures with a private
      `Fixture` helper copied from `GeminiProviderTests.swift`:
  - `parsesTextChunks`: the lines of `claude/stream.jsonl` through `parse` give exactly five
    `.text` values, and joined they read "Hello there, I'm Aash, your little pixel buddy, happy to help!".
  - `parsesSuccessResult`: the last line of `stream.jsonl` →
    `.result(isError: false, message: "Hello there, I'm Aash, your little pixel buddy, happy to help!")`.
  - `parsesErrorResult`: the last line of `bad-model.jsonl` gives `.result(isError: true, …)`
    whose message starts with "There's an issue with the selected model".
  - `ignoresOtherLines`: `""`, `"not json"`, `#"{"type":"system","subtype":"status"}"#`, and
    a `content_block_delta` whose `delta.type` is `"input_json_delta"` → `.other` each.
  - `buildsArguments`: `arguments(question: "-5 plus 3?", system: "Be brief.", model: "haiku")`
    equals the array in step 3 with those values. `"--"` is second to last, and the question is last.
  - `listsCandidates`: `candidates(home: URL(fileURLWithPath: "/Users/x"))` maps to the paths
    `/Users/x/.local/bin/claude`, `/opt/homebrew/bin/claude` and `/usr/local/bin/claude`.
  - `locatesExecutable`: in a fresh temp folder, `missing` doesn't exist, `plain` is a file with
    permissions `0o644`, and `tool` is a file with `0o755`. `locate(in: [missing, plain, tool])`
    is `tool`, and `locate(in: [missing, plain])` is nil.
  - `streamsFromAProcess`: write a temp script `#!/bin/sh` + `cat '<path of claude/stream.jsonl>'`
    with permissions `0o755`. `ClaudeCodeProvider(executable: script, workingDirectory: <temp folder>)`.
    Collect `stream([ChatMessage(role: .user, text: "hi")], system: "x")`: the joined chunks
    equal the reply text above, and the stream ends without throwing.
  - `throwsClaudeError`: the same with `bad-model.jsonl` throws `Failure.claude(message:)`.
  - `throwsNoResultWithoutResultLine`: a script that prints only the first `text_delta` line of
    the fixture throws `Failure.noResult`.
  - `throwsLaunchForMissingExecutable`: an executable path that doesn't exist throws `Failure.launch`.
  - `cancellingKillsTheProcess`: a script `echo $$ > '<temp>/pid'`, then prints one
    `text_delta` line, then `exec sleep 30`. Read the first chunk in a `Task`, then cancel that
    task and await it. Read the pid from the file. Within 3 s (check every 100 ms with
    `Task.sleep`), `kill(pid, 0)` is non-zero. The whole test takes under 5 s.
- [ ] `grep -n "unchecked\|waitUntilExit\|print(" Sources/AashAI/ClaudeCodeProvider.swift` finds nothing

## Out of scope

- The button, the setting, and finding `claude` at app start: T24.
- Sending the earlier conversation to Claude. Only the last user message goes.
- A timeout. The user closes the popover to stop it.
- Any other CLI flags, `--bare`, `--resume`, tools or MCP.

## Notes

- Test scripts: write them with `String.write(to:atomically:encoding:)`, then set
  `FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath:)`. Put each test
  in its own `FileManager.default.temporaryDirectory/UUID` folder, because Swift Testing runs
  tests in parallel.
- If `streamsFromAProcess` hangs, the parent still holds the pipe's write end. Add
  `try? pipe.fileHandleForWriting.close()` after `run()`. The prototype didn't need it.
- In the app, `claude` is a child process with its own memory: 160 MB peak for about 3 s. Aash's
  own footprint doesn't change.
