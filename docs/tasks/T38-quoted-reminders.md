# T38 · Quoted reminder phrases

Phase 5 · Target: AashCore · Risk: low · Detail: full

## Goal

A reminder phrase wrapped in quote marks, like `'remind me to wave test one at 3:45 am'`, is
read like the same phrase without them. Today the leading quote hides the trigger, so the message
goes to Gemini as normal chat. That's what happened in the T22 and T23 manual checks.

## Read first

- `Sources/AashCore/ReminderPhraseParser.swift`: `body(_:)`
- `Tests/AashCoreTests/ReminderPhraseParserTests.swift`: the `rows` table and the `on(...)` helper

## Files

- edit `Sources/AashCore/ReminderPhraseParser.swift`: `body(_:)` only
- edit `Tests/AashCoreTests/ReminderPhraseParserTests.swift`

## Interfaces

No public changes. `isReminderRequest` and `parse` keep their signatures. Update the doc comment
of `isReminderRequest` to: "True when `text` starts with a trigger, in any case, after leading
spaces and quote marks."

## Steps

1. In `body(_:)`, after the whitespace trim: if the first character is one of the quote marks
   `"`, `'`, `` ` ``, `“` (U+201C), `”` (U+201D), `‘` (U+2018) or `’` (U+2019), drop every
   leading character in that set and every trailing character in that set. Then trim whitespace
   again. If the first character isn't a quote mark, change nothing. A phrase like
   `remind me to buy 'milk' and eggs at 6` keeps its inner quotes.
2. Keep the trigger loop as it is, working on the result.
3. Add the test rows below.

## Rules

- AashCore stays Foundation-only. No force unwraps.
- Don't touch `title(_:cutting:)`. It already trims punctuation at both ends.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings
- [ ] New rows in `rows` (default `now` = `on(18, 10)`), each parsing to the given title and due:
  - `'remind me to call mum at 7'` → "Call mum", `on(18, 19)`
  - `"remind me to call the bank tomorrow at 9am"` → "Call the bank", `on(19, 9)`
  - `“reminder: dentist on Friday”` → "Dentist", `on(23, 9)`
  - `‘remember to water the plants at 8’` → "Water the plants", `on(18, 20)`
  - `  'remind me to pay rent on Sunday'  ` (spaces outside the quotes) → "Pay rent", `on(25, 9)`
- [ ] New `@Test func quotedTriggerIsAReminderRequest`: `isReminderRequest` is true for
      `'remind me to x'` and `“remind me tomorrow”`, and false for `'hello'` and `"what's up"`.
- [ ] New `@Test func innerQuotesStay`: `parse("remind me to buy 'milk' and eggs at 7", now: on(18, 10), calendar: phraseIST)?.title == "Buy 'milk' and eggs"`.
- [ ] Every existing row still passes.

## Out of scope

- Stripping quotes from messages that go to Gemini.
- Any change to the trigger list or the date rules.

## Notes

- `title` trims punctuation, apostrophes included, from both ends of the title. So a quote at the
  very end of a title is dropped ("buy 'milk' at 7" gives "Buy 'milk"). That's why
  `innerQuotesStay` puts words after the quoted word. Leave that behaviour alone.
