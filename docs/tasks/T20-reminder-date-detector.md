# T20 · Reminder date detector

Phase 4 · Target: AashCore · Risk: medium · Detail: full

## Goal

`ReminderDateDetector.detect(_:)` finds the date or time in a reminder phrase and describes it
without reference to today's date, as a `DateMatch`. `NSDataDetector` does most of the work. Two
small patterns cover what it misses ("at 6", "in 2 hours"). T35 turns a `DateMatch` into a real
date.

## Read first

- `docs/reminders.md#phrase-parsing-t20-t35` and `#what-nsdatadetector-returns`: the probe table
  is the ground truth for this card
- `docs/patterns.md#tests`

## Files

- create `Sources/AashCore/DateMatch.swift`
- create `Sources/AashCore/ReminderDateDetector.swift`
- create `Tests/AashCoreTests/ReminderDateDetectorTests.swift`

## Interfaces

```swift
// DateMatch.swift
import Foundation

/// A date or time found in a reminder phrase, described without reference to today's date.
public struct DateMatch: Equatable, Sendable {
    /// Which day the phrase names.
    public enum Day: Equatable, Sendable {
        /// No day is named: "at 6", "4:30pm", "midnight".
        case unspecified
        /// Days after today: "today" and "tonight" 0, "tomorrow" 1, "day after tomorrow" 2.
        case relative(Int)
        /// A weekday by name, numbered as `Calendar` does: 1 is Sunday, 7 is Saturday.
        case weekday(Int)
        /// A calendar date; `year` is nil unless the phrase has a four-digit year.
        case date(year: Int?, month: Int, day: Int)
    }

    /// Which time the phrase names.
    public enum Time: Equatable, Sendable {
        /// No time is named: "on Friday", "25 October".
        case unspecified
        /// A time that can't mean morning or evening: am/pm, 24-hour, or a word such as "evening".
        case exact(hour: Int, minute: Int)
        /// A clock hour 1–12 with no am or pm: "at 6", "6:30".
        case clock(hour: Int, minute: Int)
        /// A delay from now: "in 2 hours".
        case later(minutes: Int)
    }

    /// Where the date phrase is in the text it was found in.
    public var range: Range<String.Index>
    /// The day the phrase names.
    public var day: Day
    /// The time the phrase names.
    public var time: Time

    /// Creates a match.
    public init(range: Range<String.Index>, day: Day, time: Time) {
        self.range = range
        self.day = day
        self.time = time
    }
}

// ReminderDateDetector.swift
import Foundation

/// Finds the date or time in a reminder phrase (docs/reminders.md#phrase-parsing-t20-t35).
public enum ReminderDateDetector {
    /// The first usable date or time in `text`, or nil when there is none.
    public static func detect(_ text: String) -> DateMatch?
}
```

## Steps

1. `DateMatch.swift`: exactly the code above.
2. `detect(_:)` tries three things in order and returns the first that gives a match:
   1. `NSDataDetector` (step 3)
   2. a delay, "in N minutes/hours" (step 6)
   3. a bare hour, "at H", "at H:MM", "at H.MM" (step 7)
3. **NSDataDetector.** Make it inside the function: `guard let detector = try? NSDataDetector(types:
   NSTextCheckingResult.CheckingType.date.rawValue)`. It isn't `Sendable`, so never put it in a
   `static let`. Run `detector.matches(in: text, range: NSRange(text.startIndex..., in: text))`.
   Take the **first** result that has a `date`, has `duration == 0`, and whose
   `Range(result.range, in: text)` isn't nil. Skip the rest. A non-zero duration is a span such as
   "finish by tomorrow", which comes back with a wrong range. Build `day` (step 4) and `time`
   (step 5) from `matched = text[range].lowercased()`. If both are `.unspecified`, the detector
   result isn't usable: go on to step 2.2.
4. **Day, from the matched text only.** Split `matched` into words on every non-letter character.
   Check in this order and use the first that applies:
   1. `matched` contains `"day after tomorrow"` → `.relative(2)`
   2. the word `tomorrow` → `.relative(1)`
   3. the word `today` or `tonight` → `.relative(0)`
   4. a weekday word → `.weekday(n)`: `sunday`, `sun` → 1; `monday`, `mon` → 2; `tuesday`, `tue`,
      `tues` → 3; `wednesday`, `wed` → 4; `thursday`, `thu`, `thur`, `thurs` → 5; `friday`, `fri` → 6;
      `saturday`, `sat` → 7. Ignore the detector's date here: "next Friday" and "Friday" mean the
      same, and T35 picks the day.
   5. a month word (`january` … `december`, plus `jan`, `feb`, `mar`, `apr`, `jun`, `jul`, `aug`,
      `sep`, `sept`, `oct`, `nov`, `dec`; `may` is both), or `matched` contains
      `/\d{1,2}[\/-]\d{1,2}/` → `.date(year:month:day:)`. Month and day come from `result.date` (step
      8). `year` is the first `/\b(\d{4})\b/` in `matched` as an `Int`, else nil. **Never** take the
      year from `result.date`, because the detector picks it relative to the real clock.
   6. otherwise `.unspecified`
5. **Time, from the matched text.** Check in this order:
   1. `matched` contains `/\d\s*(?:a\.m\.|p\.m\.|am\b|pm\b)/` → `.exact(hour:minute:)` from
      `result.date` (step 8)
   2. one of the words `morning`, `afternoon`, `evening`, `night`, `tonight`, `noon`, `midnight` →
      `.exact` from `result.date`
   3. a digit time: first try `/(\d{1,2})[:.](\d{2})/`, and only if that finds nothing,
      `/\bat\s+(\d{1,2})\b/`. Let `hourText` be the first capture of the pattern that matched. If `hourText` has two digits starting with `0`, or its value is 0 or 13–23 →
      `.exact` from `result.date`. If the value is 1–12 → `.clock(hour: value, minute:)`, with the
      minute from the second capture, or 0 when there isn't one. Anything else → `.unspecified`.
   4. otherwise `.unspecified`
6. **Delay.** `text.firstMatch(of: /(?i)\bin\s+(\d{1,3}|an|a)\s+(minutes|minute|mins|min|hours|hour|hrs|hr)\b/)`.
   The count is 1 for `a`/`an`, else the number. Minutes = count × 60 for an hour word, × 1 for a
   minute word. Return `DateMatch(range: match.range, day: .unspecified, time: .later(minutes:))`.
7. **Bare hour.** `text.firstMatch(of: /(?i)\bat\s+(\d{1,2})(?:[:.](\d{2}))?\b/)`. Hour 0–23 and
   minute 0–59, otherwise no match. Hour 1–12 without a leading zero → `.clock`, otherwise `.exact`.
   Return `DateMatch(range: match.range, day: .unspecified, time: …)`. The range includes "at".
8. **Reading `result.date`.** The detector works in the Mac's own time zone, so read hour, minute,
   month and day with `Calendar.current.dateComponents([.month, .day, .hour, .minute], from: date)`.
   Never use a calendar passed in from outside: in the tests that's IST, and on this Mac it happens
   to match, so the mistake would go unseen.
9. The tests below. Then `./scripts/check.sh`.

## Rules

- AashCore imports only Foundation (`docs/architecture.md#targets`).
- No clock-relative fact may come from `result.date`: no day offset, weekday or year. Only hour,
  minute, month and day. That's what keeps the tests the same on any day.
- Swift 6: no non-`Sendable` value in a `static let` (`NSDataDetector`, `DateFormatter`). Regex
  literals inside functions are fine.
- No `!` force unwraps (CLAUDE.md, Style).

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Tests in `ReminderDateDetectorTests.swift`. One parameterised `@Test` over this table, each
  row giving `(text, matched, day, time)`. It expects `String(text[match.range]) == matched`,
  `match.day == day` and `match.time == time`:

  | text | matched | day | time |
  |---|---|---|---|
  | `remind me to call the bank tomorrow at 9am` | `tomorrow at 9am` | `.relative(1)` | `.exact(hour: 9, minute: 0)` |
  | `remind me to pay the electricity bill tomorrow evening` | `tomorrow evening` | `.relative(1)` | `.exact(hour: 18, minute: 0)` |
  | `remind me to call mum tomorrow afternoon` | `tomorrow afternoon` | `.relative(1)` | `.exact(hour: 15, minute: 0)` |
  | `remind me to pay rent on Friday` | `Friday` | `.weekday(6)` | `.unspecified` |
  | `remind me to book tickets next Friday at 5 pm` | `next Friday at 5 pm` | `.weekday(6)` | `.exact(hour: 17, minute: 0)` |
  | `remind me to call mum at 6 on Friday` | `at 6 on Friday` | `.weekday(6)` | `.clock(hour: 6, minute: 0)` |
  | `reminder: dentist at 4:30pm` | `4:30pm` | `.unspecified` | `.exact(hour: 16, minute: 30)` |
  | `remind me to call papa tonight` | `tonight` | `.relative(0)` | `.exact(hour: 19, minute: 0)` |
  | `remind me to submit the form on 25 October` | `25 October` | `.date(year: nil, month: 10, day: 25)` | `.unspecified` |
  | `remind me to call mum on 25 Oct 2027` | `25 Oct 2027` | `.date(year: 2027, month: 10, day: 25)` | `.unspecified` |
  | `remind me to pay fees on 25/10` | `25/10` | `.date(year: nil, month: 10, day: 25)` | `.unspecified` |
  | `remind me to call Ravi at 6:30` | `6:30` | `.unspecified` | `.clock(hour: 6, minute: 30)` |
  | `Remind me to call mum at 7:00` | `7:00` | `.unspecified` | `.clock(hour: 7, minute: 0)` |
  | `remind me to call mum at 7 tomorrow` | `at 7 tomorrow` | `.relative(1)` | `.clock(hour: 7, minute: 0)` |
  | `remind me to call mum today at 5` | `today at 5` | `.relative(0)` | `.clock(hour: 5, minute: 0)` |
  | `remind me to call mum at 19:00` | `19:00` | `.unspecified` | `.exact(hour: 19, minute: 0)` |
  | `remind me to call mum at midnight` | `midnight` | `.unspecified` | `.exact(hour: 0, minute: 0)` |
  | `remind me to renew passport day after tomorrow` | `day after tomorrow` | `.relative(2)` | `.unspecified` |
  | `remind me to call mum at 7` | `at 7` | `.unspecified` | `.clock(hour: 7, minute: 0)` |
  | `remind me to call mum at 7.30` | `at 7.30` | `.unspecified` | `.clock(hour: 7, minute: 30)` |
  | `remind me to take medicine in 2 hours` | `in 2 hours` | `.unspecified` | `.later(minutes: 120)` |
  | `remind me to call mum in 30 minutes` | `in 30 minutes` | `.unspecified` | `.later(minutes: 30)` |
  | `remind me to call mum in an hour` | `in an hour` | `.unspecified` | `.later(minutes: 60)` |

- [ ] One parameterised `@Test` `findsNothing`, where each text gives `nil`: `remind me to buy milk`,
  `what time is it in London?`, `remind me to finish by tomorrow` (a span, skipped),
  `remind me to do yoga at 0630`

## Out of scope

- Turning a `DateMatch` into a `Date`, triggers and titles: T35.
- "at 7 in the evening", "on the 25th", "half an hour", Hindi words such as "kal": the detector
  misses them and the Gemini fallback (T22) handles them. Don't add patterns for them.
- Caching the detector.

## Notes

- `Range(nsRange, in: text)` turns the detector's `NSRange` into a `Range<String.Index>`.
- Swift Regex: `text.firstMatch(of: /…/)` returns a match whose `.range` is in `text`, and whose
  captures are `Substring`s (`match.1`, `match.2`, optional for `(?: … )?` groups). Run the
  delay and bare-hour patterns on `text` itself, not on a lowercased copy, so the range stays valid.
  The `(?i)` flag makes them ignore case. The probe compiled a regex literal like these on this Mac.
- "tonight" comes back as 19:00, "tomorrow evening" as 18:00, "tomorrow morning" as 09:00 and
  "tomorrow afternoon" as 15:00. A date with no time comes back as 12:00, which step 5 turns into
  `.unspecified` because no time words or digits are in the text.
- If a row fails only at certain times of day, say so in your report rather than adjusting the row.
