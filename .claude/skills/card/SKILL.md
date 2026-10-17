---
name: card
description: Writes one new task card from an idea or a bug report, in the full card format, and adds it to the board. Use when the user types /card <idea> or /card fix: <what's broken>.
argument-hint: "<idea> | fix: <what's broken>"
disable-model-invocation: true
model: opus
effort: high
---

# Write a card for: $ARGUMENTS

Don't write app code. Write the spec that lets a cheaper model do it right.

1. Read `docs/tasks/_template.md`, `docs/tasks/BOARD.md`, and the docs and source files the idea
   touches.
2. For a bug (`fix: ...`), find the cause first: follow the code path, and read the newest log in
   `build/logs/` if it's relevant. The card should name the cause, not just the symptom.
3. Take the next free id (T27, T28, ...). Fill in every section of the template. Choose `Model`
   and `Reviewer` with the rule in `docs/WORKFLOW.md#choosing-a-model`.
4. Add the row to `BOARD.md` with status `todo` and the right `Needs`.
5. Commit: `git add -A`, then `git commit -m "Card Txx: <title>"`.
6. Tell the user in 3 lines: the card id and title, the model it will use, and that `/next` will
   run it.
