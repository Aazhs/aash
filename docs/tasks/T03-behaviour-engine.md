# T03 · Behaviour engine

Phase 1 · Target: AashCore · Risk: medium · Detail: full

## Goal

`BehaviourEngine` implements `docs/behaviour.md` exactly: a pure, seeded state machine that turns
events into `BuddyOutput`. The tests below are the spec in executable form.

## Read first

- `docs/behaviour.md`: all of it. It's the specification; this card adds the code shape and tests.
- `docs/patterns.md#random-numbers` and `docs/patterns.md#tests`

## Files

- create `Sources/AashCore/ClockSchedule.swift`
- create `Sources/AashCore/BuddyTypes.swift` (`Pose`, `BuddyEvent`, `BuddyOutput`, `Activity`)
- create `Sources/AashCore/BehaviourConfig.swift`
- create `Sources/AashCore/BehaviourEngine.swift`
- create `Sources/AashCore/SplitMix64.swift` (exactly as in `docs/patterns.md#random-numbers`, made `public`)
- create `Tests/AashCoreTests/BehaviourEngineTests.swift`
- keep `Sources/AashCore/AashCore.swift` and its test as they are

## Interfaces

The types in `docs/behaviour.md#types` exactly (all `public`), plus:

```swift
// BehaviourConfig.swift
/// Timings for the behaviour engine. Defaults are docs/behaviour.md#timings.
public struct BehaviourConfig: Equatable, Sendable {
    public var blinkEvery: ClosedRange<Double> = 3...6
    public var blinkLength: Double = 0.15
    public var walkEvery: ClosedRange<Double> = 300...900
    public var walkSpeed: Double = 18
    public var minWalkDistance: Double = 24
    public var walkFPS: Double = 8
    public var restLength: ClosedRange<Double> = 2...6
    public var waveLength: Double = 6
    public var waveLead: Double = 5
    public var waveFPS: Double = 4
    public var cheerLength: Double = 0.6
    public var areaTimeout: Double = 2
    public var afterChatDelay: Double = 60
    public var nightStartHour: Int = 23
    public var nightEndHour: Int = 7
    public var maxStep: Double = 0.5
    public var calendar: Calendar = .current
    public init() {}
    public static let standard = BehaviourConfig()
}

// BehaviourEngine.swift
/// The buddy's state machine (docs/behaviour.md). Pure: time comes in with every call.
public struct BehaviourEngine: Sendable {
    /// The latest output; the same value `handle` returned last.
    public private(set) var output: BuddyOutput
    /// What the buddy is doing.
    public private(set) var activity: Activity
    public init(config: BehaviourConfig = .standard, seed: UInt64, now: Date)
    @discardableResult
    public mutating func handle(_ event: BuddyEvent, now: Date) -> BuddyOutput
}
```

## Steps

1. Write `ClockSchedule`, the four types in `BuddyTypes.swift`, `BehaviourConfig` and
   `SplitMix64` as specified.
2. Give the engine these private stored properties (names are a suggestion; behaviour isn't):
   `config`, `rng: SplitMix64`, `offset`, `facingLeft`, `pose`, `target`,
   `lastMove: Date`, `nextBlinkAt: Date`, `blinkEndsAt: Date?`, `nextWalkAt: Date`,
   `areaDeadline: Date`, `restEndsAt: Date`, `waveEndsAt: Date`, `cheerEndsAt: Date`,
   `waveAt: Date?` (from `reminderAt`), `chatOpen = false`, `walkingEnabled = true`,
   `frameToggle = false`, `wasNightWhenPaused = false`.
3. `init`: `rng = SplitMix64(seed:)`; `nextBlinkAt = now + random(blinkEvery)`, then
   `nextWalkAt = now + random(walkEvery)` (in that order); activity `night` if it's night at
   `now`, else `idle`; compute `output`.
4. Write a private `random(_ range: ClosedRange<Double>) -> Double` using
   `Double.random(in: range, using: &rng)`. Every random pick goes through it.
5. Write `handle(_:now:)` as a `switch` on the event, following the Events table, and the
   numbered Ticks list for `.tick`. Finish every call by recomputing `output` from the state:
   pose from activity (see the States table), `needsWalkArea` from activity and offset, and
   `schedule` from the States table's schedule column.
6. Write private helpers for the repeated moves: `snapHome`, `enterIdle(now:)` (fresh next blink,
   and a fresh next walk), `enterNight`, `startWaving(now:)`, `startWalkingHome(now:)`,
   `giveUpWalk(now:)`, `isNight(_:)`, `nextNightStart(after:)`, `nightEnd(after:)`.
7. Write the tests below. Run `./scripts/check.sh --target AashCore` while working (this card runs
   in parallel with T01); finish with it passing. The orchestrator runs the full check.

## Rules

- Never call `Date()`, `Date.now`, `Calendar.current` (except as the config default) or unseeded
  randomness inside the engine.
- The engine imports Foundation only.
- Moving: `step = walkSpeed × min(now − lastMove, maxStep)`; never overshoot the target or 0.
- Frame flipping: entering `walkingOut`, `walkingHome` or `waving` sets `frameToggle = false`. Each
  tick in those activities flips it first, then sets the pose: walking → `walk` when true, `idle`
  when false; waving → `waveHigh` when true, `wave` when false. So the first tick of a walk shows
  `walk`, and the event that starts waving shows `wave`.
- Build every future date as `now.addingTimeInterval(x)`.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS`
- [ ] Tests in `Tests/AashCoreTests/BehaviourEngineTests.swift`, inside
  `@Suite struct BehaviourEngineTests`, using these helpers in the same file:

  ```swift
  let ist = TimeZone(identifier: "Asia/Kolkata")!
  var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = ist; return c }
  /// 2026-10-<day> h:m:00 IST, plus `s` seconds.
  func at(_ h: Int, _ m: Int, _ s: Double = 0, day: Int = 18) -> Date {
      calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: m))!.addingTimeInterval(s)
  }
  /// Fixed ranges so every random pick is known.
  var config: BehaviourConfig {
      var c = BehaviourConfig.standard
      c.calendar = calendar
      c.blinkEvery = 4...4
      c.walkEvery = 600...600
      c.restLength = 3...3
      return c
  }
  /// Same as `config`, with blinks pushed far away so they don't get in the way.
  var quiet: BehaviourConfig { var c = config; c.blinkEvery = 10_000...10_000; return c }
  /// ClockSchedules equal within 1 ms.
  func same(_ a: ClockSchedule, _ b: ClockSchedule) -> Bool {
      switch (a, b) {
      case (.stopped, .stopped): true
      case let (.once(x), .once(y)): abs(x.timeIntervalSince(y)) < 0.001
      case let (.every(x), .every(y)): abs(x - y) < 0.001
      default: false
      }
  }
  ```

  Tests (each `@Test`, in this order):
  - `startsIdleWaitingForFirstBlink`: `config`, init at 10:00 → activity `idle`, pose `idle`,
    offset 0, `needsWalkArea` false, `facingLeft` false, schedule `.once(at: 10:00:04)`
  - `blinksThenOpensEyes`: tick at 10:00:04 → pose `blink`, schedule `.once(at: 10:00:04 + 0.15)`;
    tick at that time → pose `idle`, schedule `.once(at: 10:00:08)`
  - `asksForRoomWhenWalkIsDue`: `quiet`, init 10:00, tick at 10:10 → activity `awaitingArea`,
    `needsWalkArea` true, schedule `.once(at: 10:10:02)`
  - `givesUpWithoutRoom`: continuing, tick at 10:10:02 → activity `idle`, `needsWalkArea` false,
    schedule `.once(at: 10:20:02)`
  - `nilAreaCancels`: `quiet`, in `awaitingArea` at 10:10, `walkArea(nil)` → activity `idle`
  - `tooSmallAreaCancels`: `walkArea(-10...0)` → activity `idle`
  - `walksOutTowardTheTarget`: `quiet`, `awaitingArea` at 10:10, `walkArea(-24...0)` at
    10:10 + 0.5 → activity `walkingOut`, `facingLeft` true, schedule `.every(seconds: 0.125)`,
    pose `idle`; tick at +0.125 → offset −2.25, pose `walk`; tick at +0.125 more → offset −4.5,
    pose `idle`
  - `restsThenWalksHome`: continuing, keep ticking every 0.125 s until activity is `resting`
    (offset −24 exactly, schedule `.once(at:)` 3 s after arrival); tick at that time → activity
    `walkingHome`, `facingLeft` false; keep ticking until activity `idle` → offset 0,
    `needsWalkArea` false
  - `lateTickMovesAtMostMaxStep`: `quiet`, walking out with `walkArea(-120...0)`, one tick 10 s
    after the walk started → offset −9 (18 × 0.5)
  - `areaShrinkSendsHome`: walking out toward −24 (`walkArea(-24...0)`), then `walkArea(-10...0)`
    → activity `walkingHome`
  - `areaGoneSnapsHome`: walking out, then `walkArea(nil)` → offset 0, activity `idle`,
    `needsWalkArea` false
  - `clickSnapsHome`: walking out, `clicked` → offset 0, activity `idle`, `facingLeft` false
  - `noWalkWhileChatOpen`: `quiet`, init 10:00, `chatOpened` at 10:05, tick at 10:10 → activity
    `idle`, `needsWalkArea` false
  - `chatCloseDelaysNextWalk`: continuing, `chatClosed` at 10:15 → schedule `.once(at: 10:16)`
  - `cheersOnReply`: `quiet`, idle at 10:00, `replyArrived` at 10:01 → pose `armsUp`, schedule
    `.once(at: 10:01 + 0.6)`; tick then → pose `idle`, activity `idle`
  - `wavesForReminder`: `quiet`, `reminderDue` at 10:01 → pose `wave`, schedule
    `.every(seconds: 0.25)`; tick +0.25 → `waveHigh`; tick +0.5 → `wave`; tick at 10:01:06 →
    activity `idle`
  - `waveAwayFromHomeEndsWalkingHome`: walking out at offset −9, `reminderDue` → `waving`; tick at
    wave end → `walkingHome`
  - `reminderAtWavesEarly`: `quiet`, init 10:00, `reminderAt(10:05)` → schedule
    `.once(at: 10:04:55)`; tick then → activity `waving`
  - `pastReminderIsIgnored`: `quiet`, init 10:00, `reminderAt(09:00)` → schedule unchanged from
    before the event
  - `pauseStopsEverything`: `paused(true)` at 10:00:01 → schedule `.stopped`, activity `paused`,
    offset 0; tick at 10:00:05 → output unchanged; `paused(false)` at 10:30 → activity `idle`,
    schedule `.once(at: 10:30:04)`
  - `pausedAtNightSleeps`: init 23:30 (night), `paused(true)` → pose `sleep`
  - `startsAsleepAtNight`: init 23:30 → activity `night`, pose `sleep`, schedule
    `.once(at: 07:00 on the 19th)`
  - `wakesUpInTheMorning`: continuing, tick at 07:00 on the 19th → activity `idle`, schedule
    `.once(at: 07:00:04 on the 19th)`
  - `fallsAsleepAt23`: `quiet`, init 22:59 → schedule `.once(at: 23:00)`; tick at 23:00 → `night`
  - `chatWakesItAtNight`: init 23:30, `chatOpened` → activity `idle`; `chatClosed`, then a tick →
    activity `night`
  - `walkingOffSendsHome`: `quiet`, init 10:00, walking out from 10:10, `walkingEnabled(false)` →
    `walkingHome`; after arriving, the schedule holds no walk: it's `.once(at: 12:46:40)`, the
    next blink (10:00 + 10,000 s)
  - `walkNowStartsAWalk`: `quiet`, idle at 10:00, `walkNow` → activity `awaitingArea`
  - `walkNowIgnoredWithChatOpen`: `chatOpened`, then `walkNow` → activity `idle`
  - `sameSeedSameOutputs`: two engines, `BehaviourConfig.standard` with the IST calendar, seed 7,
    init 10:00; 30 times: tick each at its own `.once` date (or +0.125 s for `.every`), and when
    `needsWalkArea` turns true, send both `walkArea(-120...0)` → the two outputs are equal at every step

## Out of scope

- Timers, views, AppKit: T04. The engine only describes when the clock should fire.
- Reading reminders: T23 just sends `reminderAt`.

## Notes

- `Calendar.nextDate(after:matching:matchingPolicy:)` returns a date strictly after `now`.
- Keep `handle` readable: one `switch` over events that calls small helpers. A 300-line file is fine.
- If a test and `docs/behaviour.md` disagree, stop and report; don't change either.
