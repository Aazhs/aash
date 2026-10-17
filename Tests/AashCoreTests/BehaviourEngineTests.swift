import Foundation
import Testing
@testable import AashCore

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

/// An engine that is awaiting an area at 10:10.
private func awaiting(_ cfg: BehaviourConfig = quiet) -> BehaviourEngine {
    var e = BehaviourEngine(config: cfg, seed: 1, now: at(10, 0))
    e.handle(.tick, now: at(10, 10))
    return e
}

/// An engine that started walking out at 10:10:00.5.
private func walking(_ area: ClosedRange<Double> = -24...0) -> BehaviourEngine {
    var e = awaiting()
    e.handle(.walkArea(area), now: at(10, 10, 0.5))
    return e
}

@Suite struct BehaviourEngineTests {
    @Test func startsIdleWaitingForFirstBlink() {
        let e = BehaviourEngine(config: config, seed: 1, now: at(10, 0))
        #expect(e.activity == .idle)
        #expect(e.output.pose == .idle)
        #expect(e.output.offset == 0)
        #expect(!e.output.needsWalkArea)
        #expect(!e.output.facingLeft)
        #expect(same(e.output.schedule, .once(at: at(10, 0, 4))))
    }

    @Test func blinksThenOpensEyes() {
        var e = BehaviourEngine(config: config, seed: 1, now: at(10, 0))
        e.handle(.tick, now: at(10, 0, 4))
        #expect(e.output.pose == .blink)
        #expect(same(e.output.schedule, .once(at: at(10, 0, 4.15))))
        e.handle(.tick, now: at(10, 0, 4.15))
        #expect(e.output.pose == .idle)
        #expect(same(e.output.schedule, .once(at: at(10, 0, 8))))
    }

    @Test func asksForRoomWhenWalkIsDue() {
        let e = awaiting()
        #expect(e.activity == .awaitingArea)
        #expect(e.output.needsWalkArea)
        #expect(same(e.output.schedule, .once(at: at(10, 10, 2))))
    }

    @Test func givesUpWithoutRoom() {
        var e = awaiting()
        e.handle(.tick, now: at(10, 10, 2))
        #expect(e.activity == .idle)
        #expect(!e.output.needsWalkArea)
        #expect(same(e.output.schedule, .once(at: at(10, 20, 2))))
    }

    @Test func nilAreaCancels() {
        var e = awaiting()
        e.handle(.walkArea(nil), now: at(10, 10))
        #expect(e.activity == .idle)
    }

    @Test func tooSmallAreaCancels() {
        var e = awaiting()
        e.handle(.walkArea(-10...0), now: at(10, 10))
        #expect(e.activity == .idle)
    }

    @Test func walksOutTowardTheTarget() {
        var e = walking()
        #expect(e.activity == .walkingOut)
        #expect(e.output.facingLeft)
        #expect(same(e.output.schedule, .every(seconds: 0.125)))
        #expect(e.output.pose == .idle)
        e.handle(.tick, now: at(10, 10, 0.625))
        #expect(abs(e.output.offset - -2.25) < 1e-9)
        #expect(e.output.pose == .walk)
        e.handle(.tick, now: at(10, 10, 0.75))
        #expect(abs(e.output.offset - -4.5) < 1e-9)
        #expect(e.output.pose == .idle)
    }

    @Test func restsThenWalksHome() {
        var e = walking()
        var t = at(10, 10, 0.5)
        var guardCount = 0
        while e.activity != .resting, guardCount < 1000 {
            t = t.addingTimeInterval(0.125)
            e.handle(.tick, now: t)
            guardCount += 1
        }
        #expect(e.activity == .resting)
        #expect(e.output.offset == -24)
        #expect(same(e.output.schedule, .once(at: t.addingTimeInterval(3))))
        t = t.addingTimeInterval(3)
        e.handle(.tick, now: t)
        #expect(e.activity == .walkingHome)
        #expect(!e.output.facingLeft)
        while e.activity != .idle, guardCount < 2000 {
            t = t.addingTimeInterval(0.125)
            e.handle(.tick, now: t)
            guardCount += 1
        }
        #expect(e.activity == .idle)
        #expect(e.output.offset == 0)
        #expect(!e.output.needsWalkArea)
    }

    @Test func lateTickMovesAtMostMaxStep() {
        var e = walking(-120...0)
        e.handle(.tick, now: at(10, 10, 10.5))
        #expect(abs(e.output.offset - -9) < 1e-9)
    }

    @Test func areaShrinkSendsHome() {
        var e = walking(-24...0)
        e.handle(.walkArea(-10...0), now: at(10, 10, 1))
        #expect(e.activity == .walkingHome)
    }

    @Test func areaGoneSnapsHome() {
        var e = walking()
        e.handle(.tick, now: at(10, 10, 0.625))
        e.handle(.walkArea(nil), now: at(10, 10, 1))
        #expect(e.output.offset == 0)
        #expect(e.activity == .idle)
        #expect(!e.output.needsWalkArea)
    }

    @Test func clickSnapsHome() {
        var e = walking()
        e.handle(.tick, now: at(10, 10, 0.625))
        e.handle(.clicked, now: at(10, 10, 1))
        #expect(e.output.offset == 0)
        #expect(e.activity == .idle)
        #expect(!e.output.facingLeft)
    }

    @Test func clickRightAfterWalkAreaSnapsHome() {
        var e = walking()
        e.handle(.clicked, now: at(10, 10, 0.5))
        #expect(e.activity == .idle)
        #expect(!e.output.facingLeft)
    }

    @Test func tickBeforeLastMoveStaysInRange() {
        var e = walking(-120...0)
        e.handle(.tick, now: at(10, 10, 1))
        e.handle(.tick, now: at(10, 9, 50))
        #expect(e.output.offset <= 0)
        #expect(e.output.offset >= -120)
        #expect(e.output.offset == -9)
    }

    @Test func noWalkWhileChatOpen() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(10, 0))
        e.handle(.chatOpened, now: at(10, 5))
        e.handle(.tick, now: at(10, 10))
        #expect(e.activity == .idle)
        #expect(!e.output.needsWalkArea)
    }

    @Test func chatCloseDelaysNextWalk() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(10, 0))
        e.handle(.chatOpened, now: at(10, 5))
        e.handle(.tick, now: at(10, 10))
        e.handle(.chatClosed, now: at(10, 15))
        #expect(same(e.output.schedule, .once(at: at(10, 16))))
    }

    @Test func cheersOnReply() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(10, 0))
        e.handle(.replyArrived, now: at(10, 1))
        #expect(e.output.pose == .armsUp)
        #expect(same(e.output.schedule, .once(at: at(10, 1, 0.6))))
        e.handle(.tick, now: at(10, 1, 0.6))
        #expect(e.output.pose == .idle)
        #expect(e.activity == .idle)
    }

    @Test func wavesForReminder() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(10, 0))
        e.handle(.reminderDue, now: at(10, 1))
        #expect(e.output.pose == .wave)
        #expect(same(e.output.schedule, .every(seconds: 0.25)))
        e.handle(.tick, now: at(10, 1, 0.25))
        #expect(e.output.pose == .waveHigh)
        e.handle(.tick, now: at(10, 1, 0.5))
        #expect(e.output.pose == .wave)
        e.handle(.tick, now: at(10, 1, 6))
        #expect(e.activity == .idle)
    }

    @Test func waveAwayFromHomeEndsWalkingHome() {
        var e = walking(-120...0)
        e.handle(.tick, now: at(10, 10, 1))
        #expect(abs(e.output.offset - -9) < 1e-9)
        e.handle(.reminderDue, now: at(10, 10, 1))
        #expect(e.activity == .waving)
        e.handle(.tick, now: at(10, 10, 7))
        #expect(e.activity == .walkingHome)
    }

    @Test func reminderAtWavesEarly() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(10, 0))
        e.handle(.reminderAt(at(10, 5)), now: at(10, 0))
        #expect(same(e.output.schedule, .once(at: at(10, 4, 55))))
        e.handle(.tick, now: at(10, 4, 55))
        #expect(e.activity == .waving)
    }

    @Test func pastReminderIsIgnored() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(10, 0))
        let before = e.output.schedule
        e.handle(.reminderAt(at(9, 0)), now: at(10, 0))
        #expect(e.output.schedule == before)
    }

    @Test func pauseStopsEverything() {
        var e = BehaviourEngine(config: config, seed: 1, now: at(10, 0))
        e.handle(.paused(true), now: at(10, 0, 1))
        #expect(e.output.schedule == .stopped)
        #expect(e.activity == .paused)
        #expect(e.output.offset == 0)
        let before = e.output
        e.handle(.tick, now: at(10, 0, 5))
        #expect(e.output == before)
        e.handle(.paused(false), now: at(10, 30))
        #expect(e.activity == .idle)
        #expect(same(e.output.schedule, .once(at: at(10, 30, 4))))
    }

    @Test func pausedAtNightSleeps() {
        var e = BehaviourEngine(config: config, seed: 1, now: at(23, 30))
        e.handle(.paused(true), now: at(23, 30))
        #expect(e.output.pose == .sleep)
    }

    @Test func startsAsleepAtNight() {
        let e = BehaviourEngine(config: config, seed: 1, now: at(23, 30))
        #expect(e.activity == .night)
        #expect(e.output.pose == .sleep)
        #expect(same(e.output.schedule, .once(at: at(7, 0, day: 19))))
    }

    @Test func wakesUpInTheMorning() {
        var e = BehaviourEngine(config: config, seed: 1, now: at(23, 30))
        e.handle(.tick, now: at(7, 0, day: 19))
        #expect(e.activity == .idle)
        #expect(same(e.output.schedule, .once(at: at(7, 0, 4, day: 19))))
    }

    @Test func fallsAsleepAt23() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(22, 59))
        #expect(same(e.output.schedule, .once(at: at(23, 0))))
        e.handle(.tick, now: at(23, 0))
        #expect(e.activity == .night)
    }

    @Test func chatWakesItAtNight() {
        var e = BehaviourEngine(config: config, seed: 1, now: at(23, 30))
        e.handle(.chatOpened, now: at(23, 30))
        #expect(e.activity == .idle)
        e.handle(.tick, now: at(23, 30, 5))
        #expect(e.activity == .idle)
        e.handle(.chatClosed, now: at(23, 30, 6))
        e.handle(.tick, now: at(23, 30, 7))
        #expect(e.activity == .night)
    }

    @Test func staleWaveDroppedOnResume() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(10, 0))
        e.handle(.reminderAt(at(10, 5)), now: at(10, 0))
        e.handle(.paused(true), now: at(10, 1))
        e.handle(.paused(false), now: at(10, 30))
        #expect(e.activity == .idle)
        e.handle(.tick, now: at(10, 30, 1))
        #expect(e.activity != .waving)
    }

    @Test func walkingOffSendsHome() {
        var e = walking(-120...0)
        e.handle(.walkingEnabled(false), now: at(10, 10, 1))
        #expect(e.activity == .walkingHome)
        var t = at(10, 10, 1)
        var count = 0
        while e.activity != .idle, count < 1000 {
            t = t.addingTimeInterval(0.125)
            e.handle(.tick, now: t)
            count += 1
        }
        #expect(e.activity == .idle)
        #expect(same(e.output.schedule, .once(at: at(10, 0).addingTimeInterval(10_000))))
    }

    @Test func walkNowStartsAWalk() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(10, 0))
        e.handle(.walkNow, now: at(10, 0))
        #expect(e.activity == .awaitingArea)
    }

    @Test func walkNowIgnoredWithChatOpen() {
        var e = BehaviourEngine(config: quiet, seed: 1, now: at(10, 0))
        e.handle(.chatOpened, now: at(10, 0))
        e.handle(.walkNow, now: at(10, 0))
        #expect(e.activity == .idle)
    }

    @Test func sameSeedSameOutputs() {
        var cfg = BehaviourConfig.standard
        cfg.calendar = calendar
        var a = BehaviourEngine(config: cfg, seed: 7, now: at(10, 0))
        var b = BehaviourEngine(config: cfg, seed: 7, now: at(10, 0))
        var t = at(10, 0)
        for _ in 0..<30 {
            switch a.output.schedule {
            case .once(let d): t = max(d, t)
            case .every(let s): t = t.addingTimeInterval(s)
            case .stopped: t = t.addingTimeInterval(0.125)
            }
            let wasAsking = a.output.needsWalkArea
            a.handle(.tick, now: t)
            b.handle(.tick, now: t)
            if a.output.needsWalkArea, !wasAsking {
                a.handle(.walkArea(-120...0), now: t)
                b.handle(.walkArea(-120...0), now: t)
            }
            #expect(a.output == b.output)
        }
    }
}
