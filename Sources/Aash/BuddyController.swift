import AashCore
import AashSprites
import Foundation
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Behaviour")

@MainActor
final class BuddyController {
    /// The engine's latest output.
    private(set) var output: BuddyOutput
    private var engine: BehaviourEngine
    private let statusItem: StatusItemController
    private let clock: AnimationClock
    private var lastActivity: Activity

    init(statusItem: StatusItemController, clock: AnimationClock = AnimationClock(), now: Date = Date()) {
        self.statusItem = statusItem
        self.clock = clock
        engine = BehaviourEngine(seed: UInt64.random(in: .min ... .max), now: now)
        output = engine.output
        lastActivity = engine.activity
    }

    /// Connects the clock and clicks, then shows the first output.
    func start() {
        clock.onTick = { [weak self] in self?.handle(.tick) }
        statusItem.onLeftClick = { [weak self] in self?.handle(.clicked) }
        // T08 turns walking on
        handle(.walkingEnabled(false))
    }

    /// Feeds one event to the engine and applies the result.
    func handle(_ event: BuddyEvent) {
        output = engine.handle(event, now: Date())
        statusItem.spriteView.show(SpriteFrame(output.pose), facingLeft: output.facingLeft,
                                   x: statusItem.spriteX(offset: output.offset))
        clock.apply(output.schedule)
        if engine.activity != lastActivity {
            lastActivity = engine.activity
            log.debug("activity: \(String(describing: self.lastActivity), privacy: .public)")
        }
    }
}
