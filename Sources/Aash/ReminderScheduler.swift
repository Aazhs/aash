import AashCore
import Foundation
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Reminders")

/// Tells the engine when the next reminder is due; keeps no timer (docs/reminders.md#the-wave-t23).
@MainActor
final class ReminderScheduler {
    /// How many days ahead each refresh reads.
    static let horizonDays = 8
    private let reminders: RemindersService
    private let send: (BuddyEvent) -> Void
    private let calendar: Calendar
    private var task: Task<Void, Never>?
    private var known: [ReminderInfo] = []

    /// `send` delivers `reminderAt` to the buddy.
    init(reminders: RemindersService, send: @escaping (BuddyEvent) -> Void, calendar: Calendar = .current) {
        self.reminders = reminders
        self.send = send
        self.calendar = calendar
    }

    /// Re-reads the reminders and sends `reminderAt` for the next one. Cancels a refresh still running.
    func refresh() {
        task?.cancel()
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            let start = self.calendar.startOfDay(for: Date())
            let end = self.calendar.date(byAdding: .day, value: Self.horizonDays, to: start) ?? start
            let found = await self.reminders.incomplete(dueFrom: start, to: end)
            guard !Task.isCancelled else { return }
            self.known = found
            // The lead matters: a reminder whose wave just started is still `waveLead` from due.
            let after = Date().addingTimeInterval(BehaviourConfig.standard.waveLead)
            let next = found.first { $0.hasTime && $0.due > after }
            self.send(.reminderAt(next?.due))
            let seconds = next.map { Int($0.due.timeIntervalSinceNow) } ?? -1
            log.debug("refresh: \(found.count, privacy: .public) reminders, next in \(seconds, privacy: .public) s")
        }
    }

    /// Incomplete reminders due on `now`'s day, counted from the last refresh.
    func countToday(now: Date = Date()) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return known.filter { $0.due >= start && $0.due < end }.count
    }
}
