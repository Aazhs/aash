import EventKit
import Foundation
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Reminders")

/// A reminder read from Apple Reminders.
struct ReminderInfo: Equatable, Sendable {
    /// `EKReminder.calendarItemIdentifier`.
    let id: String
    let title: String
    let due: Date
    /// False for a reminder due on a day with no time set.
    let hasTime: Bool
}

/// Why a Reminders call failed.
enum RemindersError: Error, Equatable {
    /// The user hasn't given full access to Reminders.
    case noAccess
}

/// Adds, removes and reads Apple Reminders through EventKit (docs/reminders.md#eventkit-t21).
@MainActor
final class RemindersService {
    /// Called after the Reminders database changes, including this app's own adds and removes.
    var onChange: (() -> Void)?

    private var store: EKEventStore?
    private var token: NSObjectProtocol?

    /// True once the user has given full access.
    static var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    /// Asks for full access the first time it's needed; true when access is granted.
    func requestAccess() async -> Bool {
        if Self.hasAccess { return true }
        guard EKEventStore.authorizationStatus(for: .reminder) == .notDetermined else { return false }
        do {
            return try await eventStore().requestFullAccessToReminders()
        } catch {
            log.error("Reminders access request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Adds a reminder due at `due` with an alarm at the same moment; returns its identifier.
    /// Throws `RemindersError.noAccess` without access, or EventKit's error if saving fails.
    func add(title: String, due: Date) async throws -> String {
        guard await requestAccess() else { throw RemindersError.noAccess }
        let store = eventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        var parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        parts.timeZone = TimeZone.current
        reminder.dueDateComponents = parts
        reminder.addAlarm(EKAlarm(absoluteDate: due))
        try store.save(reminder, commit: true)
        log.debug("added reminder")
        onChange?()
        return reminder.calendarItemIdentifier
    }

    /// Removes the reminder with `id`. Does nothing if it's already gone.
    func remove(id: String) throws {
        if !Self.hasAccess { throw RemindersError.noAccess }
        let store = eventStore()
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        try store.remove(reminder, commit: true)
        onChange?()
    }

    /// Incomplete reminders due in `from..<to`, soonest first. Empty without access; never asks for it.
    func incomplete(dueFrom from: Date, to: Date) async -> [ReminderInfo] {
        guard Self.hasAccess else { return [] }
        let store = eventStore()
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: from, ending: to, calendars: nil)
        let found = await withCheckedContinuation { continuation in
            Self.fetch(store, predicate) { continuation.resume(returning: $0) }
        }
        return found.filter { $0.due >= from && $0.due < to }.sorted { $0.due < $1.due }
    }

    /// Creates the one store on first use and watches it for changes.
    private func eventStore() -> EKEventStore {
        if let store { return store }
        let made = EKEventStore()
        store = made
        token = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: made, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
        return made
    }

    /// Nonisolated so EventKit's background completion isn't treated as main-actor code.
    nonisolated private static func fetch(_ store: EKEventStore, _ predicate: NSPredicate,
                                          done: @escaping @Sendable ([ReminderInfo]) -> Void) {
        store.fetchReminders(matching: predicate) { reminders in
            done((reminders ?? []).compactMap { info($0) })
        }
    }

    nonisolated private static func info(_ reminder: EKReminder) -> ReminderInfo? {
        guard let parts = reminder.dueDateComponents, let due = Calendar.current.date(from: parts) else { return nil }
        return ReminderInfo(id: reminder.calendarItemIdentifier, title: reminder.title ?? "",
                            due: due, hasTime: parts.hour != nil)
    }
}
