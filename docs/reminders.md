# Reminders

Tasks live in Apple's Reminders app, not in a database of ours. They alert on the Mac (the user's phone is Android, so there's no phone sync), they
alert through the system, and the buddy only adds, reads and waves.

## Flow

```
"remind me to submit the lab report at 6"
        │  (chat, T22)
        ▼
ReminderPhraseParser (AashCore, T35) ── trigger but no date ──> Gemini json() fallback (T22, T36)
        │ title + due date
        ▼
RemindersService.add (EventKit, T21): due date + an alarm at the due time
        │
        ├─> Reminders shows the alert at the due time, on the Mac
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
- Saving and removing are synchronous EventKit calls for one item, run on the main actor.
  Fetching runs through a nonisolated helper, so the background completion isn't treated as
  main-actor code (T21 has the probed code).

## The wave (T23)

`ReminderScheduler` keeps no timer. It finds the next incomplete reminder with a due date (today
or later) and sends `reminderAt(due)`; the engine folds it into its single clock and waves 5 s
before (`docs/behaviour.md`). The scheduler refreshes:

- at launch
- on `EKEventStoreChanged`
- when the buddy resumes from `paused` (a reminder may have been due while the screen was off)
- when the engine starts a reminder wave, so the following reminder gets scheduled

## Morning count

When the right-click menu opens, it shows "3 reminders today" (or nothing when there are none).
It's counted at that moment from the list `ReminderScheduler` read at its last refresh. That list
covers today and the next 7 days, and every change to Reminders refreshes it. No fetch runs when
the menu opens, because an open menu may not redraw when an async answer arrives. No background
check.

## Phrase parsing (T20, T35)

`ReminderPhraseParser.parse(_ text: String, now: Date, calendar: Calendar) -> ParsedReminder?`
(T35) returns a title and a due date, or nil when the text isn't a reminder or has no usable date
or time. `ReminderDateDetector.detect(_:)` (T20) finds the date phrase and describes it as a
`DateMatch`, a day and a time that don't depend on today's date. The parser resolves that against
`now`.

| Rule | Example → result (said Sunday 18 Oct 2026, 10:00 IST) |
|---|---|
| Triggers, at the start, any case: "remind me to", "remind me", "reminder:", "remember to". A trigger ending in a letter must not run into another letter | "Remind me to call mum at 7" → title "Call mum"; "remind meeting notes" → not a reminder |
| The date and time come from `NSDataDetector`; "at H", "at H:MM", "at H.MM" and "in N minutes/hours" are matched by small patterns because the detector misses them | "…tomorrow at 9am" → 19 Oct 09:00; "…in 2 hours" → 12:00 |
| Only hour, minute, month and day are read from the detector's date. The day (today, tomorrow, a weekday) and the year come from the words, because the detector counts from the real clock | |
| The title is the text minus the trigger and the date phrase. "at", "on" or "by" just before the date and "to" just after it are dropped. Spaces and punctuation are trimmed and the first letter capitalised | "remind me to submit the lab report at 6" → "Submit the lab report"; "remind me tomorrow to call mum" → "Call mum" |
| Clock hour 1–12 without am or pm: choose the first time after `now` among h:00 and (h+12):00, today then tomorrow, that falls between 07:00 and 22:59; if none does, the first one after `now` | "at 6", said at 10:00 → 18:00 today; said at 19:00 → 18:00 tomorrow |
| The same with a stated day: only that day's two times are candidates | "tomorrow at 7" → 07:00 tomorrow; "at 6 tomorrow" → 18:00 tomorrow |
| A date with no time | that day at 09:00 |
| A weekday: the next one after today; a weekday that is today means next week's. "next" and "this" change nothing | "on Friday" → Fri 23 Oct; "on Sunday" → Sun 25 Oct |
| A date without a year: this year's, or next year's if it has passed | "on 5 October" → 5 Oct 2027 |
| A time already passed today, with nothing saying which day | tomorrow |
| A result that isn't after `now` (a stated day or year already past) | nil |
| No date or time found, or a span such as "by tomorrow" | nil (the chat then tries Gemini) |
| An empty title after removing the rest | nil |

### What NSDataDetector returns

Probed on 19 Oct 2026 at 03:00 IST on this Mac (en, Asia/Kolkata), through JXA. "→ NONE" means
no match.

| Phrase | Matched | Date it gave |
|---|---|---|
| remind me to call mum at 7 / at 6 / at 8 | NONE | |
| remind me to call mum at 7.30 | NONE | |
| remind me to take medicine in 2 hours / in 30 minutes / in an hour | NONE | |
| remind me to pay the bill on the 25th | NONE | |
| remind me to call mum at 7 in the evening | NONE | |
| remind me to call the bank tomorrow at 9am | tomorrow at 9am | Tue 09:00 |
| remind me to pay the electricity bill tomorrow evening | tomorrow evening | Tue 18:00 |
| remind me to buy milk tomorrow morning | tomorrow morning | Tue 09:00 |
| remind me to call mum tomorrow afternoon | tomorrow afternoon | Tue 15:00 |
| remind me to call mum tomorrow night | tomorrow night | Tue 19:00 |
| remind me to call papa tonight | tonight | Mon 19:00 |
| remind me to call mum at 10 tonight | at 10 tonight | Mon 22:00 |
| remind me to call mum tomorrow at 7 | tomorrow at 7 | Tue **19:00** |
| remind me to call mum at 7 tomorrow | at 7 tomorrow | Tue 19:00 |
| remind me to call mum at 6 tomorrow | at 6 tomorrow | Tue 18:00 |
| remind me to call mum today at 5 | today at 5 | Mon 17:00 |
| remind me to call Ravi at 6:30 | 6:30 | Mon **06:30** |
| Remind me to call mum at 7:00 | 7:00 | Mon 07:00 |
| remind me to call mum at 19:00 | 19:00 | Mon 19:00 |
| reminder: dentist at 4:30pm | 4:30pm | Mon 16:30 |
| remind me submit assignment by 11 pm | 11 pm | Mon 23:00 |
| remind me to eat at noon | noon | Mon 12:00 |
| remind me to call mum at midnight | midnight | Tue 00:00 |
| remind me to pay rent on Friday | Friday | Fri 23 Oct **12:00** |
| remind me to pay rent on Monday (said on a Monday) | Monday | Mon 26 Oct (next week) |
| remind me to book tickets next Friday at 5 pm | next Friday at 5 pm | Fri 23 Oct 17:00 (this week's) |
| remind me to call mum at 6 on Friday | at 6 on Friday | Fri 18:00 |
| remind me to submit the form on 25 October | 25 October | 25 Oct 12:00 |
| remind me to call mum on 25 Oct 2027 | 25 Oct 2027 | 25 Oct 2027 12:00 |
| remind me to pay fees on 25/10 | 25/10 | 25 Oct 12:00 |
| remind me to call mum on 10/11 | 10/11 | 10 Nov (day first: depends on the locale, so not in tests) |
| remind me to renew passport day after tomorrow | day after tomorrow | Wed 12:00 |
| remind me tomorrow to call mum | tomorrow | Tue 12:00 |
| remind me to finish by tomorrow | finish by tomorrow | today 12:00, duration 86400 (a span) |
| remind me to call mum at 5:45 in the morning | 5:45 | Mon 05:45 ("in the morning" left over) |

A date with no time comes back as 12:00. The detector can't be given a reference date, and it
works in the Mac's own time zone.

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
`isReminder == false`, or a `due` in the past, means the chat replies normally instead. The
fallback runs only for a message that starts with a trigger; any other message never costs a
second request. The exact wording is in T36 (`ReminderFallback`).
