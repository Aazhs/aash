# Behaviour

`BehaviourEngine` (in `AashCore`) decides what the buddy does. It's a pure struct: you call
`handle(event, now:)` and it returns a `BuddyOutput`: the pose to show, which way it faces, how
far from home it is, whether it needs room to walk, and when the clock should fire next. It
never reads the clock or uses unseeded randomness, so every behaviour can be tested with fixed
dates.

## Types

```swift
public enum ClockSchedule: Equatable, Sendable {
    case stopped                 // no timer at all
    case once(at: Date)          // one tick at that time
    case every(seconds: Double)  // a tick every N seconds
}

public enum Pose: String, CaseIterable, Sendable {
    case idle, blink, walk, armsUp, wave, waveHigh, sleep   // same names as SpriteFrame
}

public enum BuddyEvent: Equatable, Sendable {
    case tick                               // AnimationClock fired
    case clicked                            // left click on the buddy
    case chatOpened, chatClosed
    case replyArrived                       // a chat reply finished
    case reminderDue                        // a reminder is about to be due
    case walkArea(ClosedRange<Double>?)     // room to walk, as offsets from home; nil = none
    case paused(Bool)                       // screen asleep, locked, Low Power, or bar hidden
    case walkingEnabled(Bool)               // the user's setting
    case walkNow                            // "Walk now" in the menu
}

public struct BuddyOutput: Equatable, Sendable {
    public var pose: Pose
    public var facingLeft: Bool
    public var offset: Double        // points from home: 0 = home, negative = left of home
    public var needsWalkArea: Bool   // true from asking for room until back home
    public var schedule: ClockSchedule
}

public enum Activity: Equatable, Sendable {
    case idle, awaitingArea, walkingOut, resting, walkingHome, waving, cheering, night, paused
}
```

## Timings (`BehaviourConfig.standard`)

| Setting | Value | Meaning |
|---|---|---|
| `blinkEvery` | 3…6 s | Gap between blinks, picked at random each time |
| `blinkLength` | 0.15 s | How long the eyes stay closed |
| `walkEvery` | 300…900 s | Gap between walks (5–15 min) |
| `walkSpeed` | 18 pt/s | Walking speed |
| `minWalkDistance` | 24 pt | A walk area shorter than this cancels the walk |
| `walkFPS` | 8 | Ticks a second while walking; the frame alternates `walk`/`idle` each tick |
| `restLength` | 2…6 s | Pause at the far end before walking home |
| `waveLength` | 6 s | How long it waves for a reminder |
| `waveFPS` | 4 | Ticks a second while waving; alternates `wave`/`waveHigh` |
| `cheerLength` | 0.6 s | `armsUp` after a chat reply |
| `areaTimeout` | 2 s | How long to wait for a walk area before giving up |
| `afterChatDelay` | 60 s | No walk sooner than this after the chat closes |
| `nightStartHour`, `nightEndHour` | 23, 7 | Night is 23:00 until 07:00, local time |
| `maxStep` | 0.5 s | A late tick moves the buddy at most this much time's worth |
| `calendar` | `.current` | Used for night; tests pass a fixed time zone |

## States

| Activity | Pose | Schedule | Leaves when |
|---|---|---|---|
| `idle` | `idle`, or `blink` while blinking | `once(at:)` the earliest of: blink start or end, next walk (if walking is enabled and the chat is closed), night start | Walk time → `awaitingArea`; night start → `night` |
| `awaitingArea` | as idle | `once(at:)` the earliest of: blink start or end, area deadline | `walkArea` with room → `walkingOut`; no room or deadline passes → `idle` |
| `walkingOut` | alternates `walk`/`idle`, facing left | `every(seconds: 1 / walkFPS)` | Reaches the target → `resting` |
| `resting` | as idle, facing left | `once(at:)` the earliest of: blink start or end, rest end | Rest ends → `walkingHome` |
| `walkingHome` | alternates `walk`/`idle`, facing right | `every(seconds: 1 / walkFPS)` | Reaches 0 → `idle` (or `night` if it's night) |
| `waving` | alternates `wave`/`waveHigh` | `every(seconds: 1 / waveFPS)` | Wave ends → `walkingHome` if away from home, else `idle` or `night` |
| `cheering` | `armsUp` | `once(at:)` cheer end | Cheer ends → `idle` |
| `night` | `sleep` | `once(at:)` next `nightEndHour`:00 | That time passes → `idle` |
| `paused` | `sleep` if it was `night`, else `idle` | `stopped` | `paused(false)` |

`needsWalkArea` is true in `awaitingArea`, `walkingOut`, `resting` and `walkingHome`, and while
`waving` away from home. It's false everywhere else.

## Events

| Event | What happens |
|---|---|
| `tick` | Advances the current activity: blinks, movement, timeouts. See "Ticks" below. |
| `walkNow` | If `idle`, walking is enabled and the chat is closed: start asking for an area now. Otherwise ignored. |
| `walkArea(range)` | In `awaitingArea`: if `range` reaches at least `minWalkDistance` left of home (`range.lowerBound <= -minWalkDistance`), pick a target at random in `range.lowerBound ... -minWalkDistance` and start `walkingOut`. Otherwise give up (back to `idle`, next walk rescheduled). While away from home: `nil` snaps home at once (the room is gone); a range that no longer contains the offset clamps the offset into it and starts `walkingHome`. |
| `clicked` | If away from home or waiting for an area: snap home (offset 0, facing right, `idle`). Waving stops too. |
| `chatOpened` | Chat counts as open. Snap home if away. From `night` the buddy wakes to `idle`. |
| `chatClosed` | Chat counts as closed. Next walk is no sooner than `now + afterChatDelay`. |
| `replyArrived` | From `idle`: `cheering` until `now + cheerLength`. Ignored in other activities. |
| `reminderDue` | Unless `paused`: `waving` until `now + waveLength`, from wherever it is (it stops walking). |
| `paused(true)` | `paused`: snap home, clock `stopped`. Remembers whether it was night. |
| `paused(false)` | From `paused`: `night` if it's night now, else `idle`. Next blink and next walk are picked fresh from `now`. |
| `walkingEnabled(false)` | No new walks. In `awaitingArea`: give up. In `walkingOut` or `resting`: start `walkingHome`. |
| `walkingEnabled(true)` | Walks allowed again. Next walk is picked fresh from `now`. |

"Snap home" means: offset 0, facing right, `needsWalkArea` false, activity `idle` (or `paused`
when pausing).

## Ticks

On `tick` at `now`:

1. **Blinking** (in `idle`, `awaitingArea`, `resting`): if a blink is showing and `now` is at or
   past its end, show `idle`. Otherwise, if `now` is at or past the next blink, show `blink`, set
   the blink end to `now + blinkLength`, and pick the next blink as `now + random(blinkEvery)`.
2. **Idle:** if it's night, enter `night`. Else if walking is enabled, the chat is closed and `now`
   is at or past the next walk: enter `awaitingArea` with a deadline of `now + areaTimeout`.
3. **Awaiting area:** if `now` is at or past the deadline, give up: `idle`, next walk is
   `now + random(walkEvery)`.
4. **Moving** (`walkingOut`, `walkingHome`): step = `walkSpeed × min(now − lastMove, maxStep)`.
   Move that far toward the target (out) or 0 (home), never past it. Flip the walk frame. Set
   `lastMove = now`. On arrival: out → `resting`, with the rest ending at
   `now + random(restLength)`; home → `idle` (or `night`), facing right, next walk
   `now + random(walkEvery)`.
5. **Resting:** at or past the rest end, start `walkingHome` with `lastMove = now`.
6. **Waving:** flip `wave`/`waveHigh`. At or past the wave end: `walkingHome` if the offset isn't
   0 (with `lastMove = now`), else `idle` or `night`.
7. **Cheering:** at or past the cheer end, `idle`.
8. **Night:** if it's no longer night, `idle`, with the next blink and next walk picked fresh.
9. **Paused:** nothing.

Night means `hour >= nightStartHour || hour < nightEndHour`, using `config.calendar`. The next
night start and end are found with `calendar.nextDate(after: now, matching:
DateComponents(hour: h, minute: 0), matchingPolicy: .nextTime)`.

## Randomness

The engine owns a `SplitMix64` seeded in `init`. Every random pick goes through it, in a fixed
order, so the same seed and the same events give the same outputs. The app seeds it from
`UInt64.random(in: .min ... .max)`; tests pass a constant, or use ranges with a single value
(`4...4`) to make every pick exact.

## The walk handshake

Walking needs room, and the engine doesn't know where that is. A `WalkStage` in the app does:

1. The engine sets `needsWalkArea = true` (activity `awaitingArea`).
2. `BuddyController` sees the change and asks the active stage to `prepare()`. The stretch stage
   widens the status item, then reports `walkArea(-(width − 22) ... 0)`. The free-walk stage reads
   the free space on the bar.
3. The engine walks within that range, reporting `offset` each tick. The stage draws the sprite at
   home + offset.
4. Back home, `needsWalkArea` turns false and the stage `finish()`es: the item shrinks, or the walk
   window hides.

If the stage can't make room, it reports `walkArea(nil)` and the walk is called off.
