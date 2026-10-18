# Run the remaining cards fast

The short version: start Claude Code, type `/next 6`, and answer when it asks you to look. Phase 4
runs by itself. It stops only for the two manual checks (T22, T23).

## How much runs in parallel

The most that can run at once is **2 cards**, and that's already the setting
(`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS = 2`). More wouldn't make it faster:

- Two cards can run together only when they change different libraries. In phase 4 that's
  **T20 ∥ T36**, and `/next` starts them together automatically.
- Every other card needs the one before it (T35 needs T20; T22 needs T21, T35 and T36). App cards
  (`Sources/Aash`) build every library, so they can't share the Mac with another card's
  half-finished code.
- The slow part is building on an 8 GB M1. Three or four builds at once would swap memory and
  finish later, and use up your Pro limit faster.

Order: **T20 + T36 together** → T35 → T21 → T22 (you check) → T23 (you check).

## Before you start (once)

1. The "Aash Local" signing certificate exists (from phase 2). Without it, macOS asks for
   Reminders access again after every build.
2. The Reminders app has at least one list (open Reminders once; "Reminders" is the default list).
3. Your Gemini key is saved in Aash's Settings (from phase 3).
4. Close VS Code or Xcode, and quit heavy apps (browsers with many tabs).

## Run it

```sh
cd ~/Codes/aash
export JOBS=6                  # faster builds; leave it out if you want to use the Mac meanwhile
claude --model sonnet
```

Then, inside Claude Code:

```
/effort medium
/next 6
```

- `/next 6` runs all six phase-4 cards one after another: implement → check → review → commit.
- The advisor (`--advisor opus`) is off here: it makes runs slower and uses more of your limit.
  Add it back only if a card keeps failing.

## When it asks you

- **T22 (reminders from chat):** it opens the app and lists steps to try in the chat. The first
  time, macOS asks for Reminders access. Click **Allow**. The chat may close; open it again and
  carry on. Alerts appear on the **Mac only** (Apple Reminders doesn't sync to Android).
- **T23 (wave before due):** add two reminders a minute apart, watch the buddy wave about 5 s
  before each alert, and check the right-click menu says "2 reminders today".
- Answer **Looks right** or **Something's off** plus a short note. A note becomes a fix round.

## If it stops

| You see | Do |
|---|---|
| A card is `blocked` | Read the reason in `docs/tasks/BOARD.md`, fix it (a permission, a key), set it back to `todo`, run `/next` again |
| Usage limit reached | Nothing is lost; finished cards are committed. Run `/next` again after the reset |
| It gets slow or forgetful | Wait for the current card to commit, `/clear`, then `/next` again with the number of cards left |
| It asks about uncommitted changes | Something was edited outside a card. Commit or discard it, then `/next` |

## After phase 4

```
/clear
/plan-phase 5
/clear
/next 3
```

`/plan-phase 5` uses Opus once to write the phase 5 cards (T24, T25, T26). The card plan then
shows whether T24 and T25 can run in parallel.
