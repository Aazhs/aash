# Reminders

Tasks live in Apple's Reminders app, not in a database of ours. They sync to the iPhone, they
alert through the system, and the buddy only adds, reads and waves.

## Flow

```
"remind me to submit the lab report at 6"
        │  (chat, T22)
        ▼
ReminderPhraseParser (AashCore, T20) ── no date found ──> Gemini json() fallback (T22)
        │ title + due date
        ▼
RemindersService.add (EventKit, T21): due date + an alarm at the due time
        │
        ├─> Reminders shows the alert at the due time, on the Mac and the iPhone
        │
        └─> EKEventStoreChanged ──> ReminderScheduler (T23) ──> buddy.handle(.reminderAt(next due))
                                                               engine waves 5 s before
```

## EventKit (T21)

- One `EKEventStore`, owned by `RemindersService`, created on first use.
- Permission: `requestFullAccessToReminders()` (macOS 14+), asked the first time a reminder is
  added, not at launch. Info.plist needs `NSRemindersFullAccessUsageDescription`:
  "Aash adds the reminders you type in its chat and waves when one is due." T21 adds it.
- Adding: `EKReminder(eventStore:)` with the title, `calendar = defaultCalendarForNewReminders()`,
  `dueDateComponents` (year to minute, plus the time zone), and
  `addAlarm(EKAlarm(absoluteDate: due))`. Save with `save(_:commit: true)`.
- Reading: `predicateForIncompleteReminders(withDueDateStarting:ending:calendars:)` and
  `fetchReminders(matching:completion:)`, wrapped in `withCheckedContinuation`. `EKReminder` isn't
  `Sendable`: map each to a small `Sendable` struct (identifier, title, due date) inside the
  completion and return those.
- Changes: observe `.EKEventStoreChanged` (`patterns.md#observers`); never poll.
- Undo: keep the identifier of the reminder just added; Undo calls `remove(_:commit: true)`.

## The wave (T23)

`ReminderScheduler` keeps no timer. It finds the next incomplete reminder with a due date (today
or later) and sends `reminderAt(due)`; the engine folds it into its single clock and waves 5 s
before (`docs/behaviour.md`). The scheduler refreshes:

- at launch
- on `EKEventStoreChanged`
- when the buddy resumes from `paused` (a reminder may have been due while the screen was off)
- when the engine starts a reminder wave, so the following reminder gets scheduled

## Morning count

When the right-click menu opens, it shows "3 reminders today" (or nothing when there are none),
fetched at that moment. No background check.

## Phrase parsing (T20)

`ReminderPhraseParser.parse(_ text: String, now: Date, calendar: Calendar) -> ParsedReminder?`
returns a title and a due date, or nil when the text isn't a reminder or has no date or time.

| Rule | Example → result |
|---|---|
| Triggers, at the start, any case: "remind me to", "remind me", "reminder:", "remember to" | "Remind me to call mum at 7" → title "Call mum" |
| The date and time come from `NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)` | "…tomorrow at 9am" → tomorrow 09:00 |
| The title is the text minus the trigger and the detected date phrase, trimmed of spaces and punctuation, first letter capitalised | "remind me to submit the lab report at 6" → "Submit the lab report" |
| Clock hour 1–12 without am or pm: choose the first time after `now` among h:00 and (h+12):00, today then tomorrow, that falls between 07:00 and 22:59; if none does, the first one after `now` | "at 6", said at 10:00 → 18:00 today; said at 19:00 → 18:00 tomorrow |
| A date with no time | that day at 09:00 |
| A time already passed today, with nothing saying which day | tomorrow |
| No date or time found | nil (the chat then tries Gemini) |
| An empty title after removing the rest | nil |

`/plan-phase 4` turns this table into T20's tests, with fixed dates and the IST time zone. Check
`NSDataDetector`'s real output for each example first: where it disagrees with a rule, the rule
wins and the parser adjusts its result.

## Gemini fallback schema (T22)

```json
{
  "type": "object",
  "properties": {
    "isReminder": { "type": "boolean" },
    "title": { "type": "string" },
    "due": { "type": "string", "description": "ISO 8601 local date-time, e.g. 2026-10-18T18:00" }
  },
  "required": ["isReminder"]
}
```

The prompt includes the current local date, time and weekday, so "next Friday" resolves correctly.
`isReminder == false`, or a `due` in the past, means the chat replies normally instead.
