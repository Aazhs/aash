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
    private let stage: WalkStage
    private let clock: AnimationClock
    private var walking = false
    /// True from asking a stage for room until the walk is over.
    var isWalking: Bool { walking }
    /// Called each time the buddy starts a reminder wave.
    var onReminderWave: (() -> Void)?
    private var prepareTask: Task<Void, Never>?
    private var lastActivity: Activity

    init(statusItem: StatusItemController, stage: WalkStage, clock: AnimationClock = AnimationClock(), now: Date = Date()) {
        self.statusItem = statusItem
        self.stage = stage
        self.clock = clock
        engine = BehaviourEngine(seed: UInt64.random(in: .min ... .max), now: now)
        output = engine.output
        lastActivity = engine.activity
        stage.onRoomChanged = { [weak self] area in self?.handle(.walkArea(area)) }
    }

    /// Connects the clock and clicks, sends the walking setting, and shows the first output.
    func start(walkingEnabled: Bool) {
        clock.onTick = { [weak self] in self?.handle(.tick) }
        statusItem.onLeftClick = { [weak self] in self?.handle(.clicked) }
        handle(.walkingEnabled(walkingEnabled))
    }

    /// Feeds one event to the engine and applies the result.
    func handle(_ event: BuddyEvent) {
        output = engine.handle(event, now: Date())
        if output.needsWalkArea && !walking {
            walking = true
            prepareTask = Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.walking, !Task.isCancelled else { return }
                let area = await self.stage.prepare()
                guard self.walking, !Task.isCancelled else { return }
                self.handle(.walkArea(area))
            }
        }
        if walking && !output.needsWalkArea && output.offset == 0 {
            walking = false
            prepareTask?.cancel()
            stage.finish()
        }
        if walking {
            stage.show(output)
        } else {
            statusItem.spriteView.show(SpriteFrame(output.pose), facingLeft: output.facingLeft,
                                       x: statusItem.spriteX(offset: output.offset))
        }
        clock.apply(output.schedule)
        if engine.activity != lastActivity {
            lastActivity = engine.activity
            log.debug("activity: \(String(describing: self.lastActivity), privacy: .public)")
            if lastActivity == .waving { onReminderWave?() }
        }
    }
}
