import Foundation
import EventKit
import SwiftUI

public enum EventKitError: LocalizedError {
    case accessDenied, restricted, fetchFailed(String)
    public var errorDescription: String? {
        switch self {
        case .accessDenied: return "Access denied. Enable in Settings."
        case .restricted: return "Access restricted."
        case .fetchFailed(let message): return "Fetch failed: \(message)"
        }
    }
}

@MainActor
public class EventKitManager: ObservableObject {
    public let store = EKEventStore()
    @Published public var isAuthorized: Bool = false
    @Published public var isReminderAuthorized: Bool = false

    public init() { checkInitialAuthorizationStatus() }

    private func checkInitialAuthorizationStatus() {
        self.isAuthorized = (EKEventStore.authorizationStatus(for: .event) == .fullAccess)
        self.isReminderAuthorized = (EKEventStore.authorizationStatus(for: .reminder) == .fullAccess)
    }

    public func requestCalendarAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        self.isAuthorized = granted
        if !granted { throw EventKitError.accessDenied }
    }
    
    public func requestReminderAccess() async throws {
        let granted = try await store.requestFullAccessToReminders()
        self.isReminderAuthorized = granted
        if !granted { throw EventKitError.accessDenied }
    }

    public func fetchActiveCalendars() -> [EKCalendar] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event)
    }
    
    public func fetchActiveReminderLists() -> [EKReminderCalendar] {
        guard isReminderAuthorized else { return [] }
        return store.reminderCalendars ?? []
    }

    public func fetchEvents(from start: Date, to end: Date, in calendars: [EKCalendar]? = nil) async throws -> [AppEvent] {
        guard isAuthorized else { return [] }
        return await Task.detached(priority: .userInitiated) { [store] in
            let cals = calendars ?? store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: cals)
            return store.events(matching: predicate).map { Self.mapToAppEvent($0) }
        }.value
    }
    
    public func fetchReminders(in lists: [EKReminderCalendar]? = nil) async throws -> [AppReminder] {
        guard isReminderAuthorized else { return [] }
        return try await Task.detached(priority: .userInitiated) { [store] in
            let targetLists = lists ?? store.reminderCalendars ?? []
            let predicate = store.predicateForReminders(in: targetLists)
            let ekReminders = try await store.reminders(matching: predicate)
            return ekReminders.map { Self.mapToAppReminder($0) }
        }.value
    }

    nonisolated public static func mapToAppEvent(_ ek: EKEvent) -> AppEvent {
        AppEvent(id: ek.eventIdentifier, title: ek.title ?? "Untitled", startDate: ek.startDate, endDate: ek.endDate, isAllDay: ek.isAllDay, location: ek.location, notes: ek.notes, hasAlarms: ek.hasAlarms, source: .eventKit, calendarID: ek.calendar.calendarIdentifier, colorHex: ek.calendar.cgColor.toHexString() ?? "#007AFF")
    }
    
    nonisolated public static func mapToAppReminder(_ ek: EKReminder) -> AppReminder {
        AppReminder(id: ek.calendarItemIdentifier ?? UUID().uuidString, title: ek.title ?? "Task", dueDate: ek.dueDateComponents?.date, isCompleted: ek.isCompleted, listID: ek.calendar.calendarIdentifier, colorHex: ek.calendar.cgColor.toHexString() ?? "#34C759")
    }

    // CREATE / UPDATE
    public func saveEvent(title: String, start: Date, end: Date, isAllDay: Bool, location: String?, notes: String?, calendarID: String, alarms: [TimeInterval], recurrenceType: RecurrenceType) async throws {
        let event = EKEvent(eventStore: store)
        event.title = title; event.startDate = start; event.endDate = end; event.isAllDay = isAllDay
        event.location = location; event.notes = notes
        event.calendar = store.calendar(withIdentifier: calendarID) ?? store.defaultCalendarForNewEvents
        
        for offset in alarms { event.addAlarm(EKAlarm(relativeOffset: offset)) }
        
        if recurrenceType != .none {
            let freq: EKRecurrenceFrequency = {
                switch recurrenceType {
                case .daily: return .daily; case .weekly: return .weekly; case .monthly: return .monthly; case .yearly: return .yearly; default: return .daily
                }
            }()
            event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: freq, interval: 1, end: nil))
        }
        
        try store.save(event, span: .thisEvent)
    }
    
    public func saveTask(title: String, dueDate: Date, notes: String?, listID: String) async throws {
        let task = EKReminder(eventStore: store)
        task.title = title; task.notes = notes
        task.calendar = store.calendar(withIdentifier: listID) ?? store.defaultCalendarForNewReminders()
        task.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        try store.save(task, commit: true)
    }

    public func toggleTaskCompletion(_ reminder: AppReminder) async throws {
        guard let ek = store.calendarItem(withIdentifier: reminder.id) as? EKReminder else { return }
        ek.isCompleted.toggle()
        try store.save(ek, commit: true)
    }
    
    public func deleteEvent(identifier: String) throws {
        if let event = store.event(withIdentifier: identifier) { try store.remove(event, span: .thisEvent) }
    }
}

extension CGColor {
    func toHexString() -> String? {
        guard let c = self.components, c.count >= 3 else { return nil }
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(c[0])*255), lroundf(Float(c[1])*255), lroundf(Float(c[2])*255))
    }
}
