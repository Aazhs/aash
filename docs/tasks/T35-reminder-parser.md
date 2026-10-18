# T35 · Reminder phrase parser

Phase 4 · Target: AashCore · Risk: medium · Detail: full

## Goal

`ReminderPhraseParser` turns "remind me to submit the lab report at 6" into a title and a due
date, on the Mac and with no network. It uses T20's `ReminderDateDetector` and applies the rules
table in `docs/reminders.md#phrase-parsing-t20-t35`. It also tells the chat whether a message is
a reminder request at all, so the Gemini fallback (T22) runs only for those.

## Read first

- `docs/reminders.md#phrase-parsing-t20-t35`: the rules table this card implements
- `Sources/AashCore/DateMatch.swift`, `ReminderDateDetector.swift` (T20): the public API only
- `docs/patterns.md#tests` (fixed dates and time zones)

## Files

- create `Sources/AashCore/ReminderPhraseParser.swift`
- create `Tests/AashCoreTests/ReminderPhraseParserTests.swift`

## Interfaces

```swift
import Foundation

/// A reminder read from a chat message.
public struct ParsedReminder: Equatable, Sendable {
    /// What to do, first letter capitalised: "Submit the lab report".
    public var title: String
    /// When it's due.
    public var due: Date

    /// Creates a parsed reminder.
    public init(title: String, due: Date) {
        self.title = title
        self.due = due
    }
}

/// Reads "remind me to … at 6" phrases (docs/reminders.md#phrase-parsing-t20-t35).
public enum ReminderPhraseParser {
    /// The phrases that start a reminder, checked in this order so "remind me to" wins over "remind me".
    public static let triggers = ["remind me to", "remind me", "reminder:", "remember to"]

    /// True when `text` starts with a trigger, in any case, after leading spaces.
    public static func isReminderRequest(_ text: String) -> Bool

    /// The title and due date in `text`, or nil when it isn't a reminder, has no usable date or
    /// time, has an empty title, or names a time that isn't after `now`.
    public static func parse(_ text: String, now: Date, calendar: Calendar) -> ParsedReminder?

    /// The first moment after `now` that `match` names, by the rules table; nil when there is none.
    static func resolve(_ match: DateMatch, now: Date, calendar: Calendar) -> Date?

    /// `text` without `range` and its joining words, tidied into a title.
    static func title(_ text: String, cutting range: Range<String.Index>) -> String
}
```

## Steps

1. **Trigger.** Write a private helper, `body(_ text: String) -> String?`. It trims leading and
   trailing whitespace, then for each trigger in order checks
   `trimmed.prefix(trigger.count).lowercased() == trigger`. When the trigger's last character is a
   letter, the character after it must be missing or not a letter, so "remind meeting" isn't a
   trigger. It returns the rest after the trigger, trimmed of whitespace, or nil when no trigger
   matches. `isReminderRequest` is `body(text) != nil`.
2. **`parse`:**
   1. `rest = body(text)`, else nil.
   2. `match = ReminderDateDetector.detect(rest)`, else nil. Detect on `rest`, not on `text`, so
      the range is in `rest`.
   3. `title = title(rest, cutting: match.range)`. Return nil if it's empty.
   4. `due = resolve(match, now:, calendar:)`, else nil.
   5. Return `ParsedReminder(title:due:)`.
3. **`title(_:cutting:)`:**
   1. `before` = the words of `text[..<range.lowerBound]`, `after` = the words of
      `text[range.upperBound...]`. Split on whitespace and drop empty pieces.
   2. If the last word of `before`, lowercased, is `at`, `on` or `by`, drop it.
   3. If the first word of `after`, lowercased, is `to`, drop it. This covers
      "remind me tomorrow to call mum".
   4. Join `before + after` with single spaces. Trim
      `.whitespacesAndNewlines.union(.punctuationCharacters)` from both ends.
   5. Capitalise the first character only: `prefix(1).uppercased() + dropFirst()`. "call Ravi"
      becomes "Call Ravi".
4. **`resolve`.** Work in `calendar` throughout. `today = calendar.startOfDay(for: now)`, and
   `day(n)` = `calendar.date(byAdding: .day, value: n, to: today)`.
   1. `.later(minutes)` → `now + minutes × 60`, if that's after `now`. The day is ignored.
   2. The days to try:
      - `.unspecified` → `[day(0), day(1)]`
      - `.relative(n)` → `[day(n)]`
      - `.weekday(w)` → `ahead = (w − weekday(now) + 7) % 7`; use `[day(ahead == 0 ? 7 : ahead)]`.
        A weekday that's today means next week's.
      - `.date(year, month, day)` → with a year, that date. Without one, the date this year, or
        next year if this year's is before `today`. An invalid date gives nil.
   3. The candidate times, for each day in order, with `calendar.date(bySettingHour:minute:second: 0, of: day)`:
      - `.unspecified` → 09:00. If the day is also `.unspecified`, return nil.
      - `.exact(h, m)` → h:m
      - `.clock(h, m)` → `(h % 12):m`, then `(h % 12 + 12):m`
   4. Pick:
      - `.clock`: the first candidate after `now` whose hour is 7–22. If none has, the first
        candidate after `now`.
      - everything else: the first candidate after `now`.
      - no candidate after `now` → nil
5. The tests below. Then `./scripts/check.sh`.

## Rules

- AashCore imports only Foundation. Pure functions only: no `Date()` and no `Calendar.current`
  in this file. `now` and `calendar` come in as arguments. The detector reads `Calendar.current`
  inside T20; that's expected.
- Tests use a Gregorian calendar in `Asia/Kolkata` and dates built from components, never
  `Date()` (`docs/patterns.md#tests`).
- No `!` force unwraps outside tests.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] In `ReminderPhraseParserTests.swift`, build `now` with a helper
  `at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10, year: Int = 2026)` in IST.
  Unless a row says otherwise, `now` is **Sunday 18 Oct 2026, 10:00 IST**. Write one
  parameterised `@Test` `parsesPhrases` over these rows (text, now, title, due):

  | text | now | title | due |
  |---|---|---|---|
  | `Remind me to call mum at 7` | | `Call mum` | 18 Oct 19:00 |
  | `REMIND ME TO call mum at 7` | | `Call mum` | 18 Oct 19:00 |
  | `remind me tomorrow to call mum` | | `Call mum` | 19 Oct 09:00 |
  | `reminder: dentist at 4:30pm` | | `Dentist` | 18 Oct 16:30 |
  | `remember to water the plants at 8` | | `Water the plants` | 18 Oct 20:00 |
  | `remind me to call the bank tomorrow at 9am` | | `Call the bank` | 19 Oct 09:00 |
  | `remind me to submit the lab report at 6` | | `Submit the lab report` | 18 Oct 18:00 |
  | `remind me to submit the lab report at 6` | 18 Oct 19:00 | `Submit the lab report` | 19 Oct 18:00 |
  | `Remind me to call Ravi at 6:30` | 18 Oct 03:00 | `Call Ravi` | 18 Oct 18:30 |
  | `remind me to call mum at 12` | | `Call mum` | 18 Oct 12:00 |
  | `remind me to call mum at 11` | 18 Oct 23:30 | `Call mum` | 19 Oct 11:00 |
  | `remind me to call mum tomorrow at 7` | | `Call mum` | 19 Oct 07:00 |
  | `remind me to call mum at 6 tomorrow` | | `Call mum` | 19 Oct 18:00 |
  | `remind me to pay rent on Friday` | | `Pay rent` | 23 Oct 09:00 |
  | `remind me to pay rent on Sunday` | | `Pay rent` | 25 Oct 09:00 |
  | `remind me to book tickets next Friday at 5 pm` | | `Book tickets` | 23 Oct 17:00 |
  | `remind me to submit the form on 25 October` | | `Submit the form` | 25 Oct 09:00 |
  | `remind me to file taxes on 5 October` | | `File taxes` | 5 Oct **2027** 09:00 |
  | `remind me to call mum on 25 Oct 2027` | | `Call mum` | 25 Oct 2027 09:00 |
  | `remind me to call mum at 7:30 am` | | `Call mum` | 19 Oct 07:30 |
  | `remind me to call mum at midnight` | | `Call mum` | 19 Oct 00:00 |
  | `remind me to call mum at 19:00` | | `Call mum` | 18 Oct 19:00 |
  | `remind me to pay the electricity bill tomorrow evening` | | `Pay the electricity bill` | 19 Oct 18:00 |
  | `remind me to call papa tonight` | | `Call papa` | 18 Oct 19:00 |
  | `remind me submit assignment by 11 pm` | | `Submit assignment` | 18 Oct 23:00 |
  | `remind me to renew passport day after tomorrow` | | `Renew passport` | 20 Oct 09:00 |
  | `remind me to take medicine in 2 hours` | | `Take medicine` | 18 Oct 12:00 |

- [ ] One parameterised `@Test` `givesNil` (text, now), each expecting nil:
  - `remind me to buy milk`: no date
  - `remind me at 6`: empty title
  - `what time is it in London?`: no trigger
  - `remind me to call mum today at 9am`: stated day, time passed
  - `remind me to call mum on 25 Oct 2025`: past year
- [ ] `isReminderRequest`: one parameterised `@Test`. `true` for `Remind me to x`,
  `  remember to x`, `reminder: x`, `remind me tomorrow`. `false` for `remind meeting notes`,
  `What's a reminder?`, `hello`.
- [ ] `resolve` without the detector: `@Test clockOnAGivenDayPrefersTheDaytimeHour`.
  `DateMatch(day: .relative(1), time: .clock(hour: 9, minute: 0))` at 18 Oct 10:00 → 19 Oct 09:00.
  For the range, use any `s.startIndex..<s.endIndex`.
- [ ] `@Test titleDropsJoiningWords`: `title("pay rent on Friday", cutting: <range of "Friday">)` →
  `"Pay rent"`.

## Out of scope

- Detection itself (T20), the Gemini fallback and the chat (T22).
- Smarter titles: removing "please", fixing case beyond the first letter.
- Recurring reminders ("every Monday").

## Notes

- 18 Oct 2026 is a Sunday, so Friday is the 23rd.
- `calendar.component(.weekday, from: now)` is 1 for Sunday in a Gregorian calendar.
- A clock hour on a stated day ("tomorrow at 7") uses the same 07:00–22:59 preference as with no
  day, so 7 means 07:00 and 6 means 18:00 (`docs/decisions.md`, 19 Oct).
- If a row's detector result doesn't match T20's table, the bug is in T20: report it, don't work
  around it here.
