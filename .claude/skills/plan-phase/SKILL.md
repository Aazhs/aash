---
name: plan-phase
description: Turns a phase's outline cards into full task cards written against the code that exists now. Run before starting phases 3, 4 and 5, for example /plan-phase 3.
argument-hint: "<phase number>"
disable-model-invocation: true
model: opus
effort: high
---

# Plan phase $ARGUMENTS

You're writing the specs that cheaper models will implement. A precise card is what lets Haiku or
Sonnet produce the result Opus would. Don't write app code.

1. Read `docs/tasks/BOARD.md`, `docs/tasks/_template.md`, and every card in phase $ARGUMENTS.
   Read one finished full card from an earlier phase as the bar for detail, such as
   `docs/tasks/T04-status-item.md`.
2. Read the docs those cards point to, and the source files they'll touch or call. Use the real
   type and function names: a card must match the code as it is now.
3. Check every external fact a card depends on: Gemini request fields, Apple API signatures,
   permission strings. Ask the `scout` subagent one question per fact, or read `Tests/Fixtures`.
4. Rewrite each card in the template's full format: exact files, exact Swift signatures, numbered
   steps, the rules that apply, tests with concrete inputs and expected outputs, a manual check if
   a person has to look, and what's out of scope. Change `Detail: outline` to `Detail: full`.
5. Split any card that would change more than about 3 files or 250 lines. Update `BOARD.md`: ids,
   `Needs`, `Model`, `Reviewer` and parallel groups. Choose models with the rule in
   `docs/WORKFLOW.md#choosing-a-model`.
6. Record any design decision you had to make in `docs/decisions.md`.
7. Commit: `git add -A`, then `git commit -m "Plan phase $ARGUMENTS"`.
8. Tell the user in at most 5 lines: the cards that are ready, the models chosen, and anything
   they must do first (a key, a permission, a certificate).
