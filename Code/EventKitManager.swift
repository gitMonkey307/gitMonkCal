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
    
    public func fetchActiveReminderLists() -> [EKCalendar] {
        guard isReminderAuthorized else { return [] }
        return store.calendars(for: .reminder)
    }

    public func fetchEvents(from start: Date, to end: Date, in calendars: [EKCalendar]? = nil) async throws -> [AppEvent] {
        guard isAuthorized else { return [] }
        return await Task.detached(priority: .userInitiated) { [store] in
            let cals = calendars ?? store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: cals)
            return store.events(matching: predicate).map { Self.mapToAppEvent($0) }
        }.value
    }
    
    public func fetchReminders(in lists: [EKCalendar]? = nil) async throws -> [AppReminder] {
        guard isReminderAuthorized else { return [] }
        let targetLists = lists ?? store.calendars(for: .reminder)
        let predicate = store.predicateForReminders(in: targetLists)
        
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).map { Self.mapToAppReminder($0) }
                continuation.resume(returning: mapped)
            }
        }
    }

    nonisolated public static func mapToAppEvent(_ ek: EKEvent) -> AppEvent {
        let alarmOffsets = ek.alarms?.map { $0.relativeOffset } ?? []
        var rec: RecurrenceType = .none
        if let rules = ek.recurrenceRules, let first = rules.first {
            switch first.frequency {
            case .daily: rec = .daily; case .weekly: rec = .weekly; case .monthly: rec = .monthly; case .yearly: rec = .yearly
            @unknown default: rec = .none
            }
        }
        
        let safeTitle = ek.title ?? "Untitled"
        let safeHex = ek.calendar.cgColor.toHexString() ?? "#007AFF"
        
        return AppEvent(
            id: ek.eventIdentifier,
            title: safeTitle,
            startDate: ek.startDate,
            endDate: ek.endDate,
            isAllDay: ek.isAllDay,
            location: ek.location,
            notes: ek.notes,
            alarms: alarmOffsets,
            recurrence: rec,
            source: .eventKit,
            calendarID: ek.calendar.calendarIdentifier,
            colorHex: safeHex
        )
    }
    
    nonisolated public static func mapToAppReminder(_ ek: EKReminder) -> AppReminder {
        let safeTitle = ek.title ?? "Task"
        let safeHex = ek.calendar.cgColor.toHexString() ?? "#34C759"
        
        return AppReminder(
            id: ek.calendarItemIdentifier,
            title: safeTitle,
            dueDate: ek.dueDateComponents?.date,
            notes: ek.notes,
            isCompleted: ek.isCompleted,
            listID: ek.calendar.calendarIdentifier,
            colorHex: safeHex
        )
    }

    public func saveEvent(id: String? = nil, title: String, start: Date, end: Date, isAllDay: Bool, location: String?, notes: String?, calendarID: String, alarms: [TimeInterval], recurrenceType: RecurrenceType) async throws {
        // EXPLICIT INSTANTIATION: Eliminates compiler type-check timeout
        let event: EKEvent
        if let safeID = id, let existing = store.event(withIdentifier: safeID) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
        }
        
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes
        event.calendar = store.calendar(withIdentifier: calendarID) ?? store.defaultCalendarForNewEvents
        
        if let existingAlarms = event.alarms { for a in existingAlarms { event.removeAlarm(a) } }
        for offset in alarms { event.addAlarm(EKAlarm(relativeOffset: offset)) }
        
        if recurrenceType != .none && event.recurrenceRules?.isEmpty != false {
            let freq: EKRecurrenceFrequency = {
                switch recurrenceType {
                case .daily: return .daily; case .weekly: return .weekly; case .monthly: return .monthly; case .yearly: return .yearly; default: return .daily
                }
            }()
            event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: freq, interval: 1, end: nil))
        } else if recurrenceType == .none, let rules = event.recurrenceRules {
            for rule in rules { event.removeRecurrenceRule(rule) }
        }
        
        try store.save(event, span: .thisEvent)
    }
    
    public func saveTask(id: String? = nil, title: String, dueDate: Date, notes: String?, listID: String) async throws {
        // EXPLICIT INSTANTIATION: Eliminates compiler type-check timeout
        let task: EKReminder
        if let safeID = id, let existing = store.calendarItem(withIdentifier: safeID) as? EKReminder {
            task = existing
        } else {
            task = EKReminder(eventStore: store)
        }
        
        task.title = title
        task.notes = notes
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
    
    public func deleteTask(identifier: String) throws {
        if let task = store.calendarItem(withIdentifier: identifier) as? EKReminder { try store.remove(task, commit: true) }
    }
}

// RESTORED: CGColor Hex String Converter
extension CGColor {
    func toHexString() -> String? {
        guard let c = self.components, c.count >= 3 else { return nil }
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(c[0])*255), lroundf(Float(c[1])*255), lroundf(Float(c[2])*255))
    }
}
