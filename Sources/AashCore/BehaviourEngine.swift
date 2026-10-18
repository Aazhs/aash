import Foundation

/// The buddy's state machine (docs/behaviour.md). Pure: time comes in with every call.
public struct BehaviourEngine: Sendable {
    /// The latest output; the same value `handle` returned last.
    public private(set) var output: BuddyOutput
    /// What the buddy is doing.
    public private(set) var activity: Activity

    private let config: BehaviourConfig
    private var rng: SplitMix64
    private var offset = 0.0
    private var facingLeft = false
    private var target = 0.0
    private var lastMove: Date
    private var nextBlinkAt: Date
    private var blinkEndsAt: Date?
    private var nextWalkAt: Date
    private var areaDeadline: Date
    private var restEndsAt: Date
    private var waveEndsAt: Date
    private var cheerEndsAt: Date
    private var waveAt: Date?
    private var chatOpen = false
    private var walkingEnabled = true
    private var frameToggle = false
    private var wasNightWhenPaused = false

    /// Starts asleep at night, otherwise idle.
    public init(config: BehaviourConfig = .standard, seed: UInt64, now: Date) {
        self.config = config
        rng = SplitMix64(seed: seed)
        lastMove = now
        nextBlinkAt = now
        nextWalkAt = now
        areaDeadline = now
        restEndsAt = now
        waveEndsAt = now
        cheerEndsAt = now
        activity = .idle
        output = BuddyOutput(pose: .idle, facingLeft: false, offset: 0, needsWalkArea: false, schedule: .stopped)
        nextBlinkAt = now.addingTimeInterval(random(config.blinkEvery))
        nextWalkAt = now.addingTimeInterval(random(config.walkEvery))
        if isNight(now) { activity = .night }
        refresh(now)
    }

    /// Applies one event at `now` and returns the new output.
    @discardableResult
    public mutating func handle(_ event: BuddyEvent, now: Date) -> BuddyOutput {
        switch event {
        case .tick: tick(now)
        case .walkNow:
            if activity == .idle, walkingEnabled, !chatOpen { askForArea(now) }
        case .walkArea(let range): receiveArea(range, now)
        case .clicked:
            if isOnWalk || activity == .awaitingArea || activity == .waving { snapHome(now) }
        case .chatOpened:
            chatOpen = true
            if activity == .night { enterIdle(now) } else if isOnWalk || activity == .awaitingArea { snapHome(now) }
        case .chatClosed:
            chatOpen = false
            nextWalkAt = max(nextWalkAt, now.addingTimeInterval(config.afterChatDelay))
        case .replyArrived:
            if activity == .idle {
                activity = .cheering
                blinkEndsAt = nil
                cheerEndsAt = now.addingTimeInterval(config.cheerLength)
            }
        case .reminderDue:
            if activity != .paused { startWaving(now) }
        case .reminderAt(let date):
            let wave = date?.addingTimeInterval(-config.waveLead)
            waveAt = (wave.map { $0 >= now } ?? false) ? wave : nil
        case .paused(let on): setPaused(on, now)
        case .walkingEnabled(let on): setWalking(on, now)
        }
        refresh(now)
        return output
    }

    // MARK: Events

    private mutating func setPaused(_ on: Bool, _ now: Date) {
        if on {
            guard activity != .paused else { return }
            wasNightWhenPaused = activity == .night
            offset = 0
            facingLeft = false
            blinkEndsAt = nil
            activity = .paused
        } else if activity == .paused {
            if let wave = waveAt, wave <= now { waveAt = nil }
            enterIdle(now)
            if isNight(now), !chatOpen { enterNight() }
        }
    }

    private mutating func setWalking(_ on: Bool, _ now: Date) {
        walkingEnabled = on
        if on {
            nextWalkAt = now.addingTimeInterval(random(config.walkEvery))
            return
        }
        switch activity {
        case .awaitingArea: giveUpWalk(now)
        case .walkingOut, .resting: startWalkingHome(now)
        default: break
        }
    }

    private mutating func receiveArea(_ range: ClosedRange<Double>?, _ now: Date) {
        switch activity {
        case .awaitingArea:
            guard let range, range.lowerBound <= -config.minWalkDistance else { return giveUpWalk(now) }
            target = random(range.lowerBound...min(range.upperBound, -config.minWalkDistance))
            activity = .walkingOut
            facingLeft = true
            frameToggle = false
            lastMove = now
            blinkEndsAt = nil
        case .walkingOut, .resting, .walkingHome, .waving:
            // Out and resting count as away even on the first step, before the offset moves.
            guard isAway || activity == .walkingOut || activity == .resting else { return }
            guard let range else { return snapHome(now) }
            guard activity == .walkingOut || activity == .resting, !range.contains(target) else { return }
            if activity == .walkingOut, target < range.lowerBound, offset >= range.lowerBound,
               range.lowerBound <= -config.minWalkDistance {
                // Wider menus came to the front ahead of the buddy: stop at their edge, don't turn back.
                target = range.lowerBound
            } else {
                startWalkingHome(now)
            }
        default: break
        }
    }

    // MARK: Ticks

    private mutating func tick(_ now: Date) {
        if activity != .paused, let wave = waveAt, now >= wave {
            waveAt = nil
            return startWaving(now)
        }
        if activity == .idle || activity == .awaitingArea || activity == .resting { blink(now) }
        switch activity {
        case .idle:
            if isNight(now), !chatOpen {
                enterNight()
            } else if walkingEnabled, !chatOpen, now >= nextWalkAt {
                askForArea(now)
            }
        case .awaitingArea:
            if now >= areaDeadline { giveUpWalk(now) }
        case .walkingOut, .walkingHome: move(now)
        case .resting:
            if now >= restEndsAt { startWalkingHome(now) }
        case .waving:
            frameToggle.toggle()
            if now >= waveEndsAt {
                if isAway { startWalkingHome(now) } else { arriveHome(now) }
            }
        case .cheering:
            if now >= cheerEndsAt { activity = .idle }
        case .night:
            if !isNight(now) { enterIdle(now) }
        case .paused: break
        }
    }

    private mutating func blink(_ now: Date) {
        if let end = blinkEndsAt {
            if now >= end { blinkEndsAt = nil }
        } else if now >= nextBlinkAt {
            blinkEndsAt = now.addingTimeInterval(config.blinkLength)
            nextBlinkAt = now.addingTimeInterval(random(config.blinkEvery))
        }
    }

    private mutating func move(_ now: Date) {
        let step = config.walkSpeed * max(0, min(now.timeIntervalSince(lastMove), config.maxStep))
        lastMove = now
        frameToggle.toggle()
        if activity == .walkingOut {
            offset = max(offset - step, target)
            if offset <= target {
                activity = .resting
                restEndsAt = now.addingTimeInterval(random(config.restLength))
            }
        } else {
            offset = min(offset + step, 0)
            if offset >= 0 { arriveHome(now) }
        }
    }

    // MARK: Moves

    private var isAway: Bool { offset != 0 }

    /// Away, or on a walk that hasn't taken its first step yet (offset still 0).
    private var isOnWalk: Bool {
        isAway || activity == .walkingOut || activity == .resting || activity == .walkingHome
    }

    private mutating func snapHome(_ now: Date) {
        offset = 0
        facingLeft = false
        blinkEndsAt = nil
        activity = .idle
        nextWalkAt = now.addingTimeInterval(random(config.walkEvery))
    }

    /// Fresh blink and walk times; used when waking up or resuming.
    private mutating func enterIdle(_ now: Date) {
        activity = .idle
        blinkEndsAt = nil
        nextBlinkAt = now.addingTimeInterval(random(config.blinkEvery))
        nextWalkAt = now.addingTimeInterval(random(config.walkEvery))
    }

    private mutating func enterNight() {
        activity = .night
        blinkEndsAt = nil
    }

    private mutating func askForArea(_ now: Date) {
        activity = .awaitingArea
        areaDeadline = now.addingTimeInterval(config.areaTimeout)
    }

    private mutating func giveUpWalk(_ now: Date) {
        activity = .idle
        nextWalkAt = now.addingTimeInterval(random(config.walkEvery))
    }

    private mutating func startWaving(_ now: Date) {
        waveAt = nil
        activity = .waving
        frameToggle = false
        blinkEndsAt = nil
        waveEndsAt = now.addingTimeInterval(config.waveLength)
    }

    private mutating func startWalkingHome(_ now: Date) {
        activity = .walkingHome
        facingLeft = false
        frameToggle = false
        blinkEndsAt = nil
        lastMove = now
    }

    /// Back at offset 0: idle, or asleep if it's night and nobody is chatting.
    private mutating func arriveHome(_ now: Date) {
        offset = 0
        facingLeft = false
        blinkEndsAt = nil
        activity = .idle
        nextWalkAt = now.addingTimeInterval(random(config.walkEvery))
        if isNight(now), !chatOpen { enterNight() }
    }

    // MARK: Time

    private func isNight(_ date: Date) -> Bool {
        let hour = config.calendar.component(.hour, from: date)
        return hour >= config.nightStartHour || hour < config.nightEndHour
    }

    private func nextHour(_ hour: Int, after date: Date) -> Date {
        config.calendar.nextDate(after: date, matching: DateComponents(hour: hour, minute: 0), matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(3600)
    }

    private func nextNightStart(after date: Date) -> Date { nextHour(config.nightStartHour, after: date) }
    private func nightEnd(after date: Date) -> Date { nextHour(config.nightEndHour, after: date) }

    // MARK: Output

    private mutating func random(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &rng)
    }

    private func pose() -> Pose {
        switch activity {
        case .idle, .awaitingArea, .resting: blinkEndsAt == nil ? .idle : .blink
        case .walkingOut, .walkingHome: frameToggle ? .walk : .idle
        case .waving: frameToggle ? .waveHigh : .wave
        case .cheering: .armsUp
        case .night: .sleep
        case .paused: wasNightWhenPaused ? .sleep : .idle
        }
    }

    private func needsWalkArea() -> Bool {
        switch activity {
        case .awaitingArea, .walkingOut, .resting, .walkingHome: true
        case .waving: isAway
        default: false
        }
    }

    private func schedule(_ now: Date) -> ClockSchedule {
        var times: [Date] = []
        if let waveAt { times.append(waveAt) }
        switch activity {
        case .idle:
            times.append(blinkEndsAt ?? nextBlinkAt)
            if walkingEnabled, !chatOpen { times.append(nextWalkAt) }
            times.append(isNight(now) && !chatOpen ? now : nextNightStart(after: now))
        case .awaitingArea:
            times += [blinkEndsAt ?? nextBlinkAt, areaDeadline]
        case .resting:
            times += [blinkEndsAt ?? nextBlinkAt, restEndsAt]
        case .walkingOut, .walkingHome: return .every(seconds: 1 / config.walkFPS)
        case .waving: return .every(seconds: 1 / config.waveFPS)
        case .cheering: times = [cheerEndsAt]
        case .night: times.append(nightEnd(after: now))
        case .paused: return .stopped
        }
        return times.min().map { .once(at: $0) } ?? .stopped
    }

    private mutating func refresh(_ now: Date) {
        output = BuddyOutput(
            pose: pose(), facingLeft: facingLeft, offset: offset,
            needsWalkArea: needsWalkArea(), schedule: schedule(now))
    }
}
