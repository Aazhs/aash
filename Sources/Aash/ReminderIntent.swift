import AashAI
import AashCore
import Foundation
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Reminders")

/// Turns a chat message into an Apple Reminders item: the local parser first, Gemini as the fallback.
@MainActor
final class ReminderIntent {
    /// What became of a message.
    enum Outcome: Equatable {
        /// Not a reminder: send it to the chat as usual.
        case notReminder
        /// Added to Reminders; `id` is for Undo.
        case added(id: String, title: String, due: Date)
        /// Reminders access is off.
        case noAccess
        /// Saving failed.
        case failed
    }

    private let reminders: RemindersService
    private let provider: any ChatProvider
    private let calendar: Calendar

    init(reminders: RemindersService, provider: any ChatProvider, calendar: Calendar = .current) {
        self.reminders = reminders
        self.provider = provider
        self.calendar = calendar
    }

    /// Reads `text` and adds the reminder it asks for.
    func handle(_ text: String) async -> Outcome {
        guard ReminderPhraseParser.isReminderRequest(text) else { return .notReminder }
        let now = Date()
        let title: String
        let due: Date
        if let parsed = ReminderPhraseParser.parse(text, now: now, calendar: calendar) {
            title = parsed.title
            due = parsed.due
            log.info("reminder read locally")
        } else if let suggestion = await fallback(text, now: now), suggestion.due > Date() {
            title = suggestion.title
            due = suggestion.due
            log.info("reminder read by Gemini")
        } else {
            log.info("not read as a reminder; sent to chat")
            return .notReminder
        }
        do {
            let id = try await reminders.add(title: title, due: due)
            return .added(id: id, title: title, due: due)
        } catch RemindersError.noAccess {
            return .noAccess
        } catch {
            log.error("Adding a reminder failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    /// Removes a reminder this chat added; false if that failed.
    func undo(id: String) -> Bool {
        do {
            try reminders.remove(id: id)
            return true
        } catch {
            log.error("Removing a reminder failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func fallback(_ text: String, now: Date) async -> ReminderSuggestion? {
        do {
            let data = try await provider.json(ReminderFallback.prompt(text, now: now, calendar: calendar),
                                               system: ReminderFallback.system,
                                               schema: ReminderFallback.schema)
            let suggestion = try ReminderFallback.suggestion(from: data, calendar: calendar)
            if suggestion == nil { log.info("reminder fallback: Gemini says not a reminder") }
            return suggestion
        } catch {
            log.error("reminder fallback failed")
            return nil
        }
    }
}
