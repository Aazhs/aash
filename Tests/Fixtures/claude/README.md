# Claude Code fixtures

Recorded 19 Oct 2026 with Claude Code 2.1.302 (`claude-haiku-5-5`), from an empty temporary folder.
The `system`/`init` line is removed from both files: it lists local paths and plugins.

| File | Command |
|---|---|
| `stream.jsonl` | `claude -p --model haiku --tools "" --strict-mcp-config --disable-slash-commands --no-session-persistence --system-prompt "You are Aash, a small pixel buddy. Be warm and brief." --output-format stream-json --verbose --include-partial-messages "Say hello in one short sentence." < /dev/null` |
| `bad-model.jsonl` | The same flags with `--model nonexistent-model-x` and the prompt `hi`. Exit status 1. |

What they show:

- One JSON object per line. Text chunks: `type == "stream_event"`, `event.type ==
  "content_block_delta"`, `event.delta.type == "text_delta"`, text in `event.delta.text`. Five
  chunks join to "Hello there, I'm Aash, your little pixel buddy, happy to help!".
- Other lines (`system` status, `message_start`, `content_block_start`/`stop`, `assistant`,
  `message_delta`, `message_stop`, `rate_limit_event`) carry no new text.
- The last line is `type == "result"`. `is_error` is false on success, and `result` repeats the
  whole reply. On failure `is_error` is true, `api_error_status` is the HTTP status (404 here), and
  `result` is a message for people.
- Cost of one call on the M1: first text after 1.7 s, finished after 2.8 s; peak memory footprint
  160 MB (maximum resident set 274 MB), in the `claude` process, not in Aash.
