import Foundation
import EventKit
import SwiftUI
import CoreLocation // For weather loc

public enum EventKitError: LocalizedError {
    case accessDenied, restricted, fetchFailed(String)
    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Access denied. Enable in Settings."
        case .restricted: return "Access restricted."
        case .fetchFailed(let msg): return "Fetch failed: \(msg)"
        }
    }
}

@MainActor
public class EventKitManager: ObservableObject {
    private let store = EKEventStore()
    @Published public var isAuthorized: Bool = false
    @Published public var isReminderAuthorized: Bool = false

    public init() { checkInitialAuthorizationStatus() }

    private func checkInitialAuthorizationStatus() {
        isAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        isReminderAuthorized = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    public func requestCalendarAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined: isAuthorized = try await store.requestFullAccessToEvents()
        case .fullAccess: isAuthorized = true
        default: throw EventKitError.accessDenied
        }
    }

    public func requestReminderAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .notDetermined: isReminderAuthorized = try await store.requestFullAccessToReminders()
        case .fullAccess: isReminderAuthorized = true
        default: throw EventKitError.accessDenied
        }
    }

    public func fetchActiveCalendars() -> [EKCalendar] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event)
    }

    public func fetchEvents(from start: Date, to end: Date, in calendars: [EKCalendar]?) async throws -> [AppEvent] {
        guard isAuthorized else { throw EventKitError.accessDenied }
        return await Task.detached { [store] in
            let targets = calendars ?? store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: targets)
            let ekEvents = store.events(matching: predicate)
            return ekEvents.compactMap { EventKitManager.mapToAppEvent($0) }
        }.value
    }

    public func fetchReminders() async throws -> [AppEvent] {
        guard isReminderAuthorized else { return [] }
        return await Task.detached { [store] in
            let today = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 30, to: today)!
            let predicate = store.predicateForReminders(in: [.default]) // Default lists
            let reminders = store.reminders(matching: predicate)
            return reminders?.compactMap { EventKitManager.mapReminderToAppEvent($0) } ?? []
        }.value
    }

    nonisolated private static func mapToAppEvent(_ ek: EKEvent) -> AppEvent {
        AppEvent(
            id: ek.eventIdentifier,
            title: ek.title ?? "Untitled",
            startDate: ek.startDate,
            endDate: ek.endDate,
            isAllDay: ek.isAllDay,
            location: ek.location,
            notes: ek.notes,
            hasAlarms: ek.hasAlarms,
            source: .eventKit,
            calendarID: ek.calendar.calendarIdentifier,
            colorHex: ek.calendar.cgColor.toHexString() ?? "#007AFF",
            recurrenceSummary: ek.recurrenceRules?.first?.frequency.description ?? nil,
            cancelled: ek.status == .canceled
        )
    }

    nonisolated private static func mapReminderToAppEvent(_ ek: EKReminder) -> AppEvent {
        AppEvent(
            id: ek.calendarItemIdentifier ?? UUID().uuidString,
            title: ek.title ?? "Untitled Task",
            startDate: ek.dueDate ?? Date(),
            endDate: ek.dueDate ?? Date(),
            isAllDay: false,
            notes: ek.body,
            source: .reminder,
            calendarID: ek.calendar.calendarIdentifier,
            colorHex: "#FF9500",
            priority: ek.priority.rawValue as Int?
        )
    }

    public func createEvent(appEvent: AppEvent, alarms: [TimeInterval], recurrence: RecurrenceRule?) async throws {
        guard isAuthorized else { throw EventKitError.accessDenied }
        try await Task.detached { [store] in
            guard let calendar = store.calendars(for: .event).first(where: { $0.calendarIdentifier == appEvent.calendarID }) else { throw EventKitError.fetchFailed("No calendar") }
            let ekEvent = EKEvent(eventStore: store)
            ekEvent.calendar = calendar
            ekEvent.title = appEvent.title
            ekEvent.startDate = appEvent.startDate
            ekEvent.endDate = appEvent.endDate
            ekEvent.isAllDay = appEvent.isAllDay
            ekEvent.location = appEvent.location
            ekEvent.notes = appEvent.notes
            ekEvent.alarms?.removeAll()
            for offset in alarms { ekEvent.addAlarm(EKAlarm(relativeOffset: offset)) }
            if let rec = recurrence {
                ekEvent.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .init(frequency: rec.frequency.ekFrequency, interval: rec.interval)!))
            }
            try store.save(ekEvent, span: .thisEvent)
        }.value
    }

    public func createReminder(appEvent: AppEvent, alarms: [TimeInterval]) async throws {
        guard isReminderAuthorized else { throw EventKitError.accessDenied }
        try await Task.detached { [store] in
            let reminder = EKReminder(eventStore: store)
            reminder.title = appEvent.title
            reminder.dueDate = appEvent.startDate
            reminder.notes = appEvent.notes
            reminder.calendar = store.defaultCalendarForNewReminders()
            reminder.alarms?.removeAll()
            for offset in alarms { reminder.addAlarm(EKAlarm(relativeOffset: offset)) }
            try store.save(reminder, commit: true)
        }.value
    }

    public func completeReminder(id: String) {
        Task.detached {
            let reminders = self.store.reminders(matching: self.store.predicateForReminders(with: nil))
            if let reminder = reminders?.first(where: { $0.calendarItemIdentifier == id }) {
                reminder.setValue(true, forKey: "completed")
                try? self.store.save(reminder, commit: true)
            }
        }
    }

    public func deleteReminder(id: String) {
        Task.detached {
            let reminders = self.store.reminders(matching: self.store.predicateForReminders(with: nil))
            if let reminder = reminders?.first(where: { $0.calendarItemIdentifier == id }) {
                try? self.store.remove(reminder, commit: true)
            }
        }
    }
}

extension RecurrenceRule.Frequency {
    var ekFrequency: EKRecurrenceFrequency {
        switch self {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        }
    }
}

extension CGColor {
    func toHexString() -> String? {
        // Existing...
        guard let components = self.components, components.count >= 3 else { return nil }
        let r = Float(components[0]), g = Float(components[1]), b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

extension EKRecurrenceFrequency {
    var description: String {
        switch self {
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        case .yearly: return "year"
        @unknown default: return ""
        }
    }
}
