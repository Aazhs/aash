# Running the agents

You type `/next`. One small task card gets implemented by a cheap model, checked by scripts,
reviewed by a second agent and committed. You look at the menu bar when a card asks you to. That's
the whole loop.

## Why cheap models can do this well

Most of what makes Opus better than Sonnet or Haiku is its decisions, not its typing. So Opus makes
the decisions once and writes them down: the docs in this folder and the task cards in
`docs/tasks/`. Cheaper models then do the typing, against checks they can run themselves.

| Technique | What it does here |
|---|---|
| Opus writes the specs | The docs and cards were written by Opus. `/plan-phase` and `/card` switch to Opus for one turn to write more. |
| The card is the whole prompt | A subagent starts with an empty memory. Each card names the exact files, Swift signatures, rules, steps and tests. |
| Patterns to copy | `docs/patterns.md` has one approved way to write each tricky thing. Cheap models copy well and invent badly. |
| Done means checks pass | `./scripts/check.sh` builds and tests. The implementer keeps going until it passes. |
| A second pair of eyes | The `reviewer` agent compares the diff with the card and the rules. Risky cards get an Opus reviewer. |
| Escalation | If a card's model fails twice, the card is retried one model up: Haiku, then Sonnet, then Opus. |
| Advisor | With `/advisor opus`, Sonnet and Haiku consult Opus at key moments: before committing to an approach, when stuck, before calling a card done. |

Work with no docs to lean on still needs Opus. That's why the free-walk card (T12) is assigned to
Opus from the start.

## One-time setup

1. **Restart Claude Code** in this folder. New agents and skills load at startup.
2. **Start with Sonnet and the Opus advisor:**
   ```
   cd ~/Codes/aash
   claude --model sonnet --advisor opus
   ```
   The flags apply to this session only. Type `/advisor opus` once instead if you want the advisor
   saved for every session (it's experimental and works without it too).
3. **Lower the effort for the chat itself:** `/effort medium`. The skills and agents set their own.
4. **Before Phase 2:** create the signing certificate ([steps below](#signing)).
5. **Before Phase 3:** get a free Gemini API key ([steps below](#gemini-key)).

## The daily loop

1. `/next` runs one card. `/next 3` runs three in a row.
2. A card with a manual check stops, launches the app and asks you to look. Answer "Looks right" or
   "Something's off" plus a note.
3. At the start of phases 3, 4 and 5, run `/plan-phase 3` (or 4, 5). Opus rewrites that phase's
   outline cards against the real code.
4. After every card or two, run `/clear`. Each card carries its own context, so nothing is lost.
5. Run `/usage` now and then to see how much each agent used.

## What happens inside /next

```
BOARD.md ──> pick the first ready card
               │
               ▼
        implementer (card's model) ──> writes code + tests, runs check.sh until it passes
               │
               ▼
        check.sh (run again by the orchestrator) ── fail ──> back to the same implementer (max 2)
               │ pass
               ▼
        reviewer (Sonnet, or Opus for risky cards) ── FIX ──> back to the same implementer (max 2)
               │ PASS
               ▼
        manual check? ──> the app opens, you look and answer
               │
               ▼
        BOARD.md: done · progress.md: one row · git commit "Txx: title"
```

If a card keeps failing, it's escalated once to the next model up. If it still fails, it's marked
`blocked` and the run stops with the reason.

## Who does what

| Job | Who | Model |
|---|---|---|
| Plan a phase, write a new card | `/plan-phase`, `/card` | Opus, for that one turn |
| Run the pipeline | `/next` | Sonnet |
| Implement a card | `implementer` | The card's `Model` column |
| Look up an Apple or Gemini API fact | `scout` | Haiku |
| Review the diff | `reviewer` | The card's `Reviewer` column |

The agents are plain files you can read and edit: `.claude/agents/*.md`. The skills are in
`.claude/skills/*/SKILL.md`. The `model:` line at the top of each one is what picks its model.

### Choosing a model

Use this rule when writing or editing a card:

- **haiku:** mechanical work from an exact spec. Porting data, wiring an existing pattern, running
  measurements, recording fixtures. One or two files, no design choices.
- **sonnet:** the default. Any card with real logic, UI, concurrency, or two or three files.
- **opus:** only when the docs don't settle the design and the API is badly documented (T12), or
  after Sonnet has failed a card twice.
- **Reviewer:** sonnet by default; opus when a mistake would be costly. That means window levels,
  energy use, concurrency, or anything that would make you uninstall the app.

## When something goes wrong

| What you see | What to do |
|---|---|
| A card is `blocked` | Read its reason on the board. Fix the cause (a missing key, a permission), set it back to `todo`, run `/next`. If the card itself is wrong, run `/card fix: <what's wrong>`. |
| Claude Code asks before an Opus agent | That's the `Agent(model:opus)` rule in `.claude/settings.json`, protecting your Pro limit. Say yes for T12 and risky reviews. |
| You hit the usage limit | Nothing breaks. Cards are committed one at a time. Run `/next` after the limit resets; an interrupted card is picked up again. |
| The app misbehaves after a card | Run `/card fix: <what you saw>`. Opus writes a fix card; `/next` runs it. |
| macOS asks for permissions again after every build | You haven't created the signing certificate yet. See [signing](#signing). |
| A script output isn't enough | The full logs are in `build/logs/`. |

## Keeping your Mac light

- **One terminal, one Claude Code session.** Subagents run inside it as API calls, not as extra
  apps. At most 2 run at once (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` in `.claude/settings.json`).
- **No Xcode and no IDE indexing.** Close VS Code's Swift extension while agents build; its
  language server indexes in the background.
- **Builds run at low priority** (`taskpolicy -c utility`, 4 jobs), so your Mac stays usable. For
  even calmer builds, run `export BUILD_QOS=background JOBS=2` before starting Claude Code; builds
  get slower.
- **Short output.** Scripts print one line each, which also saves tokens.

## Saving your Pro limit

- Start sessions with `--model sonnet`. Opus only runs where a skill or card asks for it.
- `/clear` between cards. A long conversation is re-read on every request.
- Prefer `/next` over chatting about code; the cards already hold the context.
- Planning is the expensive part, and it happens once per phase.

## Skip these for now

| Feature | Why not here |
|---|---|
| Agent teams | Each teammate is a separate Claude Code process and they use several times the tokens. |
| Dynamic workflows, `ultracode` | Fan out many agents at once: great for big audits, wasteful for building one small app on Pro. |
| Git worktrees for parallel work | Each worktree rebuilds from scratch: more CPU, more disk. Parallel pairs here share one build folder instead. |
| Cloud sessions (`claude --cloud`) | They run on Linux and can't build a Mac app. |
| Browser or screen-control tools | Screenshots are heavy. You check the menu bar yourself when a card asks. |

## Parallel cards

Two cards can run at once only when the board gives them the same parallel group (such as `P1`) and
they change different libraries. While working, each implementer compiles only its own library with
`./scripts/check.sh --target <name>`, so the other card's half-finished code can't break it. When
both finish, `/next` runs the full check, then reviews and commits each card separately.

There's one pair to start with: T01 (sprite art, Haiku) and T03 (behaviour engine, Sonnet).

## Signing

macOS remembers permissions (Reminders, Accessibility) per app signature. An ad-hoc signature
changes with every build, so macOS would ask again after each one. A self-signed certificate keeps
the signature stable. It's about 2 minutes, once:

1. Open **Keychain Access** (Spotlight: "Keychain Access").
2. Menu **Keychain Access → Certificate Assistant → Create a Certificate…**
3. Name: `Aash Local`. Identity Type: **Self Signed Root**. Certificate Type: **Code Signing**.
   Click Create, then Done.
4. Run `./scripts/build.sh`. The first time, macOS asks whether `codesign` may use the key: choose
   **Always Allow**. The build line should end with `signed: Aash Local`.

## Gemini key

1. Go to [aistudio.google.com](https://aistudio.google.com), sign in, and choose **Get API key →
   Create API key**. No billing is needed for the free tier.
2. Your Jio Gemini Pro plan doesn't add API credits; the free tier is separate and enough for a
   personal buddy. Your project's limits are on AI Studio's usage page. The daily limit resets at
   midnight Pacific time (12:30 PM IST, or 1:30 PM IST from November to March).
3. For T14, in the terminal you start Claude Code from: `export GEMINI_API_KEY="your key"`. Never
   put the key in a file in this repo.
4. Once the app has Settings (T18), paste the key there. It's stored in the Keychain.
5. On the free tier, Google may use your prompts to improve its products. Don't send secrets
   through the buddy.

## Words used here

- **Card:** one small task in `docs/tasks/`, with everything needed to do it.
- **Subagent:** a separate Claude conversation, started by the main session, with its own model
  and a fresh memory. Defined in `.claude/agents/`.
- **Skill:** a saved set of instructions you run with a slash command, such as `/next`. Defined in
  `.claude/skills/`.
- **Advisor:** a stronger model the working model can ask for guidance mid-task.
- **Orchestrator:** the main session while `/next` runs. It starts agents, runs checks and commits.
