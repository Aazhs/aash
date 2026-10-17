# T20 · Reminder phrase parser

Phase 4 · Target: AashCore · Risk: medium · Detail: outline

## Goal

`ReminderPhraseParser` turns "remind me to submit the lab report at 6" into a title and a due
date on the Mac, following the rules in `docs/reminders.md#phrase-parsing-t20`, with no network.

## Read first

- `docs/reminders.md#phrase-parsing-t20`
- `docs/patterns.md#tests` (fixed dates and time zones)

## Files (expected)

- create `Sources/AashCore/ReminderPhraseParser.swift`
- create `Tests/AashCoreTests/ReminderPhraseParserTests.swift`

## Sketch

```swift
public struct ParsedReminder: Equatable, Sendable {
    public var title: String
    public var due: Date
}
public enum ReminderPhraseParser {
    public static func parse(_ text: String, now: Date, calendar: Calendar) -> ParsedReminder?
}
```

## Done when (to be detailed by /plan-phase 4)

- [ ] A parameterised test per row of the rules table, plus at least 10 phrasings (Indian English
  included: "remind me to pay the electricity bill tomorrow evening"), with fixed `now` in IST.
  `/plan-phase 4` first checks what `NSDataDetector` returns for each phrase on this Mac.
- [ ] `./scripts/check.sh` prints `CHECK PASS`
