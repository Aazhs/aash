---
name: next
description: Runs the next ready task card through the agent pipeline (implement, check, review, commit). Use when the user types /next, optionally with a count such as /next 3.
argument-hint: "[how many cards, default 1]"
disable-model-invocation: true
model: sonnet
effort: medium
---

# Run the next card

How many cards to run: `$ARGUMENTS` (empty means 1). Run them one after another. You're the
orchestrator: you start subagents, run checks, update the board and commit. You don't write app
code yourself.

## 0. Before the first card

Run `git status --short`. If there are uncommitted changes that don't belong to a card marked
`doing` on the board, stop and ask the user what to do with them.

## 1. Pick a card

1. Read `docs/tasks/BOARD.md`. Take the first row whose status is `todo` and whose `Needs` cards
   are all `done`. A card left `doing` by an interrupted run counts as ready; resume it.
2. If that card's file says `Detail: outline`, stop: tell the user to run `/plan-phase <phase>` first.
3. If the row has a parallel group (for example `P1`) and the other card in that group is also
   ready, run both as a parallel pair (section 8).
4. No ready card: list the blocked cards with their reasons, and stop.
5. Set the card's status to `doing` on the board.

## 2. Implement

Start the `implementer` subagent. Pass the card's `Model` column as the model (`haiku`, `sonnet`
or `opus`) and this task: "Implement `docs/tasks/<card file>`. Read the whole card first."

Its report starts with `RESULT:`. If it says `blocked`, go to section 5.

## 3. Check

Run `./scripts/check.sh` yourself. On `CHECK FAIL`, send the output to the same implementer with
SendMessage (so it keeps its context): "check.sh failed; fix it and report again." At most 2
rounds; then go to section 5.

## 4. Review

Start the `reviewer` subagent. Pass the card's `Reviewer` column as the model, and this task:
"Review card `docs/tasks/<card file>`. check.sh output: <the three result lines>."

On `VERDICT: FIX`, send the numbered list to the same implementer with SendMessage, then repeat
sections 3 and 4. At most 2 review rounds; then go to section 5.

## 5. Escalate (once per card)

Start a fresh implementer one model up (haiku → sonnet → opus). Give it the card plus a summary
of at most 5 lines of what went wrong. Then repeat sections 3 and 4. Choosing opus makes Claude
Code ask the user first; that's intended, because Opus uses the Pro limit fastest.

Still failing, or already on opus: set the card to `blocked` on the board with a one-line reason,
log it (section 7), and stop the run.

## 6. Manual check

If the card has a "Manual check" section, follow it. Usually that means: run `./scripts/run.sh`,
then ask the user the section's question with AskUserQuestion, with the options "Looks right" and
"Something's off". Some sections also ask you to run a measurement while the user does something,
or to put what the user pastes into a doc; do those steps in the order written.

For "Something's off", send the user's note to the implementer as a fix round (back to section 3).

## 7. Finish the card

1. Set the card's status to `done` on the board.
2. Add a row to `docs/progress.md`: date · card · implementer model (and any escalation) · fix
   rounds · one-line note.
3. Commit: `git add -A`, then `git commit -m "Txx: <card title>"`. Never push.
4. Print 3 lines: what changed, the `CHECK` line, and the next ready card.

After every second card, suggest `/clear` to the user. Each card carries its own context, so
clearing costs nothing and keeps usage down.

## 8. Parallel pair

- Only for two cards in the same parallel group that change different library targets.
- Start both implementers in the background at the same time. Add to each task: "This is a
  parallel card. While working, use `./scripts/check.sh --target <its target>`, not the full check."
- When both have reported, run the full `./scripts/check.sh` once. Send each failure to the
  implementer that owns the file it's in.
- Then review each card separately (section 4), and finish each card separately (section 7), so
  each gets its own commit.

## Rules for you

- Keep messages short. Don't paste whole files or logs into the chat.
- Edit only `docs/tasks/BOARD.md` and `docs/progress.md` yourself.
- Never skip the review. Never mark a card done without `CHECK PASS`.
