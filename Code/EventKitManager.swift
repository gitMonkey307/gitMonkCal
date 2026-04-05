import Foundation
import EventKit

@MainActor
public class EventKitManager: ObservableObject {
    public let store = EKEventStore()
    @Published public var isAuthorized: Bool = false
    
    public func requestAccess() async throws {
        let eStatus = try await store.requestFullAccessToEvents()
        let rStatus = try await store.requestFullAccessToReminders()
        self.isAuthorized = eStatus && rStatus
    }
    
    public func fetchItems(from start: Date, to end: Date) async throws -> [AppEvent] {
        guard isAuthorized else { return [] }
        
        // 1. Fetch Events
        let ePredicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: ePredicate)
        let events = ekEvents.map { EventKitManager.mapToAppEvent($0) }
        
        // 2. Fetch Tasks (Reminders)
        let rPredicate = store.predicateForReminders(in: nil)
        let ekReminders = try await store.reminders(matching: rPredicate)
        let tasks = ekReminders.map { EventKitManager.mapToAppTask($0) }
        
        return events + tasks
    }
    
    public func saveItem(title: String, start: Date, end: Date, notes: String?, isTask: Bool, calendarID: String) throws {
        if isTask {
            let task = EKReminder(eventStore: store)
            task.title = title
            task.notes = notes
            task.calendar = store.defaultCalendarForNewReminders()
            try store.save(task, commit: true)
        } else {
            let event = EKEvent(eventStore: store)
            event.title = title; event.startDate = start; event.endDate = end; event.notes = notes
            event.calendar = store.calendar(withIdentifier: calendarID) ?? store.defaultCalendarForNewEvents
            try store.save(event, span: .thisEvent)
        }
    }
    
    nonisolated private static func mapToAppEvent(_ ek: EKEvent) -> AppEvent {
        AppEvent(id: ek.eventIdentifier, title: ek.title ?? "Untitled", startDate: ek.startDate, endDate: ek.endDate, isAllDay: ek.isAllDay, location: ek.location, notes: ek.notes, colorHex: ek.calendar.cgColor.toHexString() ?? "#007AFF", isTask: false, calendarID: ek.calendar.calendarIdentifier)
    }
    
    nonisolated private static func mapToAppTask(_ r: EKReminder) -> AppEvent {
        let date = r.dueDateComponents?.date ?? Date()
        return AppEvent(id: r.calendarItemIdentifier, title: r.title ?? "Task", startDate: date, endDate: date, isAllDay: true, notes: r.notes, colorHex: r.calendar.cgColor.toHexString() ?? "#FF9500", isTask: true, isCompleted: r.isCompleted, calendarID: r.calendar.calendarIdentifier)
    }
}

extension CGColor {
    func toHexString() -> String? {
        guard let c = self.components, c.count >= 3 else { return nil }
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(c[0])*255), lroundf(Float(c[1])*255), lroundf(Float(c[2])*255))
    }
}
