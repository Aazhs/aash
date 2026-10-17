import Foundation

/// A pose the buddy can show; same names as SpriteFrame.
public enum Pose: String, CaseIterable, Sendable {
    case idle, blink, walk, armsUp, wave, waveHigh, sleep
}

/// Something that happened, fed to the behaviour engine.
public enum BuddyEvent: Equatable, Sendable {
    /// AnimationClock fired.
    case tick
    /// Left click on the buddy.
    case clicked
    case chatOpened, chatClosed
    /// A chat reply finished.
    case replyArrived
    /// Wave now.
    case reminderDue
    /// The next reminder's due time; nil = none.
    case reminderAt(Date?)
    /// Where a walk may end, as offsets from home; nil = no room.
    case walkArea(ClosedRange<Double>?)
    /// Screen asleep, locked, Low Power, or bar hidden.
    case paused(Bool)
    /// The user's setting.
    case walkingEnabled(Bool)
    /// "Walk now" in the menu.
    case walkNow
}

/// What the buddy should look like and when the clock should fire next.
public struct BuddyOutput: Equatable, Sendable {
    public var pose: Pose
    public var facingLeft: Bool
    /// Points from home: 0 = home, negative = left of home.
    public var offset: Double
    /// True from asking for room until back home.
    public var needsWalkArea: Bool
    public var schedule: ClockSchedule
}

/// What the buddy is doing.
public enum Activity: Equatable, Sendable {
    case idle, awaitingArea, walkingOut, resting, walkingHome, waving, cheering, night, paused
}
