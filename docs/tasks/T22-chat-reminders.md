# T22 · Reminders from chat

Phase 4 · Target: Aash + AashAI · Risk: medium · Detail: outline

## Goal

Typing a reminder in the chat creates it: the local parser first, Gemini's JSON reply as the
fallback. The chat shows a confirmation line ("Added: Submit the lab report · today 6:00 PM") with
an Undo button.

## Read first

- `docs/reminders.md#flow`, `#gemini-fallback-schema-t22`
- `docs/ai.md#requests-the-app-makes`
- `Sources/AashCore/ReminderPhraseParser.swift`, `Sources/Aash/RemindersService.swift`, the chat
  view controller

## Files (expected)

- edit `Sources/Aash/ChatViewController.swift` (detect, confirm, undo)
- create `Sources/Aash/ReminderIntent.swift` (local parse → fallback → add)

## Done when (to be detailed by /plan-phase 4)

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Manual: three phrasings create correct reminders; one that only Gemini understands works;
  Undo removes the reminder; ordinary questions still get normal replies
