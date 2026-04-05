import Foundation
import EventKit
import SwiftUI

public enum EventKitError: LocalizedError {
    case accessDenied
    case restricted
    case fetchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied: return "Calendar access denied. Enable in Settings."
        case .restricted: return "Access restricted."
        case .fetchFailed(let message): return "Fetch failed: \(message)"
        }
    }
}

@MainActor
public class EventKitManager: ObservableObject {
    private let store = EKEventStore()
    @Published public var isAuthorized: Bool = false
    @Published public var isReminderAuthorized: Bool = false

    public init() {
        checkInitialAuthorizationStatus()
    }

    private func checkInitialAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        self.isAuthorized = (status == .fullAccess)
        
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        self.isReminderAuthorized = (reminderStatus == .fullAccess)
    }

    public func requestCalendarAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            let granted = try await store.requestFullAccessToEvents()
            self.isAuthorized = granted
            guard granted else { throw EventKitError.accessDenied }
        case .restricted: throw EventKitError.restricted
        case .denied, .writeOnly: throw EventKitError.accessDenied
        case .fullAccess: self.isAuthorized = true
        @unknown default: throw EventKitError.accessDenied
        }
    }
    
    public func requestReminderAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .notDetermined:
            let granted = try await store.requestAccess(to: .reminder)
            self.isReminderAuthorized = granted
            guard granted else { throw EventKitError.accessDenied }
        case .restricted: throw EventKitError.restricted
        case .denied: throw EventKitError.accessDenied
        case .fullAccess: self.isReminderAuthorized = true
        @unknown default: throw EventKitError.accessDenied
        }
    }

    public func fetchActiveCalendars() -> [EKCalendar] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event)
    }
    
    public func fetchActiveReminderLists() -> [EKReminderCalendar] {
        guard isReminderAuthorized else { return [] }
        return store.reminderCalendars ?? []
    }

    public func fetchEvents(from startDate: Date, to endDate: Date, in calendars: [EKCalendar]? = nil) async throws -> [AppEvent] {
        guard isAuthorized else { throw EventKitError.accessDenied }
        return await Task.detached(priority: .userInitiated) { [store] in
            let targetCalendars = calendars ?? store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: targetCalendars)
            let ekEvents = store.events(matching: predicate)
            return ekEvents.map { Self.mapToAppEvent($0) }
        }.value
    }
    
    public func fetchReminders(in lists: [EKReminderCalendar]? = nil) async throws -> [EKReminder] {
        guard isReminderAuthorized else { throw EventKitError.accessDenied }
        return await Task.detached { [store] in
            let targetLists = lists ?? store.reminderCalendars ?? []
            let predicate = store.predicateForReminders(in: targetLists)
            return store.reminders(matching: predicate) ?? []
        }.value
    }

    nonisolated private static func mapToAppEvent(_ ekEvent: EKEvent) -> AppEvent {
        let hexColor = ekEvent.calendar.cgColor.toHexString() ?? "#007AFF"
        return AppEvent(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "Untitled",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            isAllDay: ekEvent.isAllDay,
            location: ekEvent.location,
            notes: ekEvent.notes,
            hasAlarms: ekEvent.hasAlarms,
            source: .eventKit,
            calendarID: ekEvent.calendar.calendarIdentifier,
            colorHex: hexColor
        )
    }
    
    static func mapToAppReminder(_ ekReminder: EKReminder) -> AppReminder {
        AppReminder(
            id: ekReminder.calendarItemIdentifier ?? UUID().uuidString,
            title: ekReminder.title ?? "Untitled Reminder",
            dueDate: ekReminder.dueDateComponents?.date,
            isCompleted: ekReminder.isCompleted,
            listID: ekReminder.calendar.calendarIdentifier
        )
    }

    public func createEvent(appEvent: AppEvent, alarms: [TimeInterval], recurrenceType: RecurrenceType) async throws {
        guard isAuthorized else { throw EventKitError.accessDenied }
        try await Task.detached(priority: .userInitiated) { [store] in
            guard let calendar = store.calendars(for: .event).first(where: { $0.calendarIdentifier == appEvent.calendarID }) else {
                throw EventKitError.fetchFailed("Calendar not found")
            }
            
            let ekEvent = EKEvent(eventStore: store)
            ekEvent.calendar = calendar
            ekEvent.title = appEvent.title
            ekEvent.startDate = appEvent.startDate
            ekEvent.endDate = appEvent.endDate
            ekEvent.isAllDay = appEvent.isAllDay
            ekEvent.location = appEvent.location
            ekEvent.notes = appEvent.notes
            
            ekEvent.alarms?.removeAll()
            for offset in alarms {
                let alarm = EKAlarm(relativeOffset: offset)
                ekEvent.addAlarm(alarm)
            }
            
            if case .none = recurrenceType {} else {
                let rule: EKRecurrenceRule
                switch recurrenceType {
                case .daily: rule = EKRecurrenceRule(dailyWithInterval: 1)!
                case .weekly: rule = EKRecurrenceRule(weeklyWithInterval: 1, daysOfTheWeek: nil, daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)!
                case .monthly: rule = EKRecurrenceRule(monthlyWithInterval: 1, daysOfTheMonth: nil, weeksOfTheMonth: nil, daysOfTheWeek: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)!
                case .yearly: rule = EKRecurrenceRule(yearlyWithInterval: 1, daysOfTheYear: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheWeek: nil, setPositions: nil, end: nil)!
                case .none: break
                }
                ekEvent.addRecurrenceRule(rule)
            }
            
            try store.save(ekEvent, span: .thisEvent)
        }.value
    }
}

extension CGColor {
    func toHexString() -> String? {
        guard let components = self.components, components.count >= 3 else { return nil }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}
