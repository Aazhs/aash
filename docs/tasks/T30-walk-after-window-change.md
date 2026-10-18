# T30 · Free walk after window change

Phase 2 · Target: AashCore + Aash · Risk: medium · Detail: full

## Goal

When another app comes to the front mid-walk and its menus reach past the buddy's target, the buddy
keeps walking and stops at the new menus' edge. Today it turns round and walks home.

## What breaks today (reproduced 18 Oct 2026)

Log of a free walk with Ghostty in front (menus end at x = 365), then an app switch about 3 s in:

```
22:27:20.331 Walk       free walk: targets -654.0 … -614.0
22:27:20.334 Behaviour  activity: walkingOut
22:27:23.000 Behaviour  activity: walkingHome      ← app switch, ~48 pt out
22:27:24.855 Behaviour  activity: idle
```

There's no `free walk off` line, so the rescan succeeded. `FreeWalkStage.rescan()` reported the new
app's `visible` range. Its `lowerBound` is the new menus' right edge, and that now lies to the
right of the target. `BehaviourEngine.receiveArea` sees a range that doesn't contain the target
and starts `walkingHome`. A full walk takes about 35 s (640 pt at 18 pt/s), so almost any app
switch with wider menus than the terminal's sends the buddy home.

## Read first

- `Sources/AashCore/BehaviourEngine.swift`, `receiveArea(_:_:)` and `move(_:)`
- `docs/behaviour.md#events`: the `walkArea(range)` row
- `Sources/Aash/FreeWalkStage.swift`, `rescan()`

## Files

- edit `Sources/AashCore/BehaviourEngine.swift`: one branch in `receiveArea`
- edit `Tests/AashCoreTests/BehaviourEngineTests.swift`: three new tests
- edit `Sources/Aash/FreeWalkStage.swift`: one debug log line in `rescan()`
- edit `docs/behaviour.md`: the `walkArea(range)` row
- edit `docs/menubar.md`: one sentence under "Rules for free walk"

## Interfaces

No new declarations. The public API doesn't change.

## Requirements

The new rule, for a non-nil `walkArea(range)` that arrives while the buddy is on a walk:

| Activity | Condition | Result |
|---|---|---|
| `walkingOut` or `resting` | `range.contains(target)` | nothing changes (as today) |
| `walkingOut` | `target < range.lowerBound` **and** `offset >= range.lowerBound` **and** `range.lowerBound <= -config.minWalkDistance` | `target = range.lowerBound`; still `walkingOut` |
| `walkingOut` | any other range without the target | `startWalkingHome(now)` (as today) |
| `resting` | range without the target | `startWalkingHome(now)` (as today) |

- `offset >= range.lowerBound` means the buddy hasn't yet passed the new edge. If it has, it's now
  over the new app's menus: `FreeWalkStage.show` already hides it there, and it walks home.
- `range.lowerBound <= -config.minWalkDistance` keeps the existing test `areaShrinkSendsHome`
  (range `-10...0`) passing unchanged: a stretch too short to start a walk doesn't continue one.
- `nil` still snaps home. `awaitingArea`, `walkingHome` and `waving` behave exactly as today.
- Nothing in `FreeSpace`, `BuddyController` or the stages changes, apart from the log line.

## Steps

1. In `BehaviourEngine.receiveArea`, replace

   ```swift
   if activity == .walkingOut || activity == .resting, !range.contains(target) {
       startWalkingHome(now)
   }
   ```

   with

   ```swift
   guard activity == .walkingOut || activity == .resting, !range.contains(target) else { return }
   if activity == .walkingOut, target < range.lowerBound, offset >= range.lowerBound,
      range.lowerBound <= -config.minWalkDistance {
       // Wider menus came to the front ahead of the buddy: stop at their edge, don't turn back.
       target = range.lowerBound
   } else {
       startWalkingHome(now)
   }
   ```

   No other line in the engine changes. `move(_:)` already clamps with `max(offset - step, target)`,
   so the buddy rests exactly at the new target.
2. Add the three tests below to `BehaviourEngineTests`, inside the existing suite, after
   `areaShrinkSendsHome`. Use the file's `walking(_:)` and `at(_:_:_:)` helpers. Don't change any
   existing test.
3. In `FreeWalkStage.rescan()`, after `plan = measure()`, add:

   ```swift
   if let plan {
       log.info("rescan: visible \(plan.visible.lowerBound, privacy: .public) … \(plan.visible.upperBound, privacy: .public)")
   }
   ```

   A nil plan already logs its reason in `measure()`. Keep everything else in `rescan()`, including
   `onRoomChanged?(plan?.visible)` (T28).
4. In `docs/behaviour.md`, in the `walkArea(range)` row (one long table line), replace

   ```
   a range that no longer contains the target starts `walkingHome`. |
   ```

   with

   ```
   a range that no longer contains the target starts `walkingHome`, except while `walkingOut`: if the target is left of the range, the buddy hasn't passed `range.lowerBound`, and `range.lowerBound <= -minWalkDistance`, the target moves to `range.lowerBound` and the walk goes on. |
   ```

5. In `docs/menubar.md`, the bullet that begins "`targets` is only the far-left band" ends with
   "so an app switch doesn't send the buddy home early." Add this sentence after it, on a new line
   indented by two spaces like the bullet's other lines:

   ```
   If the new app's menus reach past the target, the buddy stops at their edge instead of turning back (T30).
   ```
6. Run `./scripts/check.sh`.

## Rules

- No new timers, no delays, no extra rescans (CLAUDE.md rule 5; `docs/menubar.md`: never scan on a
  timer).
- `AashCore` stays free of AppKit (rule 3).
- Comments explain why. No `print`; the log line uses the file's existing `log`.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Tests (one `@Test` each, in `BehaviourEngineTests.swift`):
  - `areaShrinkAheadMovesTarget`: `var e = walking(-120 ... -100)` (target is somewhere in
    -120 … -100). Then `e.handle(.walkArea(-50...0), now: at(10, 10, 1))` → `e.activity ==
    .walkingOut`. Then tick every 0.125 s from `at(10, 10, 1)` until `e.activity != .walkingOut`
    (guard count < 1000) → `e.activity == .resting` and `e.output.offset == -50`.
  - `areaShrinkBehindSendsHome`: `var e = walking(-120 ... -100)`, then 14 ticks at
    `at(10, 10, 0.5 + Double(i) * 0.125)` for `i` in 1…14 → `abs(e.output.offset - -31.5) < 1e-9`.
    Then `e.handle(.walkArea(-28...0), now: at(10, 10, 2.25))` → `e.activity == .walkingHome`.
  - `restingAreaShrinkSendsHome`: `var e = walking(-120 ... -100)`, tick every 0.125 s until
    `e.activity == .resting` (guard count < 1000). Then `.walkArea(-90...0)` at the next 0.125 s →
    `e.activity == .walkingHome`.
- [ ] `areaShrinkSendsHome`, `areaGoneSnapsHome` and every other existing test still pass unchanged.

## Manual check

1. Run `./scripts/run.sh`. Free walk must be on ("Walk on the Whole Bar") and the terminal in front.
   Then start a log capture in the background (`log show` afterwards loses the debug lines):
   `/usr/bin/log stream --predicate 'subsystem == "me.aarshj.aash"' --info --debug --style compact > <scratchpad>/t30.log`.
   Use `/usr/bin/log`: in zsh, plain `log` is a shell builtin.
2. Ask: "Right-click → Walk now. Within about 10 s, while the buddy is still near its icon, ⌘-Tab
   to an app with more menus than the terminal, such as Safari or Mail. Does the buddy keep walking
   left and stop just right of that app's menus, instead of turning back?"
3. Stop the capture. If the answer is no, put the `rescan: visible`, `free walk off` and
   `activity:` lines from `t30.log` in the report.

## Out of scope

- Walking further when the new app's menus are shorter. The buddy keeps its old target and stops
  short of the new edge, which is fine.
- Changing `FreeSpace`, the target band, `WalkWindow` or the full-screen behaviour.
- Keeping the last good plan when a scan fails. The log showed no failed scan.
- Any change to how the engine starts a walk (`awaitingArea`).

## Notes

- `walking(-120 ... -100)` picks a target at random in `-120 ... min(-100, -24)` = `-120 ... -100`,
  so every target is left of -90, -50 and -28: the tests hold for any seed.
- The first tick after `walking(_:)` is at 0.625 s and moves 2.25 pt (`walksOutTowardTheTarget`),
  so 14 ticks give -31.5.
- Write ranges with a negative upper bound as `-120 ... -100`, with spaces: `-120...-100` doesn't
  parse.
