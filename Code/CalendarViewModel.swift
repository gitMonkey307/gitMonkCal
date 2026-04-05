import Foundation
import SwiftUI
import Combine
import EventKit

@MainActor
public class CalendarViewModel: ObservableObject {
    @Published public var groupedEvents: [Date: [AppEvent]] = [:]
    @Published public var allReminders: [AppEvent] = []
    @Published public var availableCalendars: [EKCalendar] = []
    @Published public var visibleCalendarIDs: Set<String> = []
    @Published public var isLoading: Bool = false
    private let eventKitManager: EventKitManager
    private var cancellables = Set<AnyCancellable>()
    public var currentViewRange: (start: Date, end: Date) = (Date(), Date())

    public init(eventKitManager: EventKitManager? = nil) {
        self.eventKitManager = eventKitManager ?? EventKitManager()
        let today = Date()
        let cal = Calendar.current
        let start = cal.date(byAdding: .year, value: -1, to: today) ?? today
        let end = cal.date(byAdding: .year, value: 1, to: today) ?? today
        self.currentViewRange = (start, end)
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification).sink { [weak self] _ in Task { await self?.refreshData() } }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .EKEventStoreChanged).sink { [weak self] _ in Task { await self?.refreshData() } }.store(in: &cancellables)
    }

    public func requestAccessAndFetch() async {
        do {
            try await eventKitManager.requestCalendarAccess()
            try await eventKitManager.requestReminderAccess()
            loadCalendars()
            await refreshData()
        } catch { print(error.localizedDescription) }
    }

    private func loadCalendars() {
        availableCalendars = eventKitManager.fetchActiveCalendars()
        if visibleCalendarIDs.isEmpty { visibleCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier }) }
    }

    public func toggleCalendarVisibility(calendarID: String) async {
        if visibleCalendarIDs.contains(calendarID) { visibleCalendarIDs.remove(calendarID) } else { visibleCalendarIDs.insert(calendarID) }
        await refreshData()
    }

    public func refreshData() async {
        guard eventKitManager.isAuthorized else { return }
        isLoading = true
        let targetCalendars = availableCalendars.filter { visibleCalendarIDs.contains($0.calendarIdentifier) }
        do {
            let rawEvents = try await eventKitManager.fetchEvents(from: currentViewRange.start, to: currentViewRange.end, in: targetCalendars)
            groupedEvents = groupEventsByDay(rawEvents)
            allReminders = try await eventKitManager.fetchReminders()
        } catch { print(error) }
        isLoading = false
    }

    private func groupEventsByDay(_ events: [AppEvent]) -> [Date: [AppEvent]] {
        let cal = Calendar.current
        var dict: [Date: [AppEvent]] = [:]
        for event in events.filter { !$0.cancelled } {
            let startOfDay = cal.startOfDay(for: event.startDate)
            let endOfDay = cal.startOfDay(for: event.endDate)
            var currentDay = startOfDay
            while currentDay <= endOfDay {
                dict[currentDay, default: []].append(event)
                currentDay = cal.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
            }
        }
        // Sort daily
        for (date, daily) in dict {
            dict[date] = daily.sorted { lhs, rhs in
                if lhs.isAllDay && !rhs.isAllDay { return true }
                if !lhs.isAllDay && rhs.isAllDay { return false }
                return lhs.startDate < rhs.startDate
            }
        }
        return dict
    }

    public func createEvent(title: String, startDate: Date, endDate: Date, isAllDay: Bool, location: String?, notes: String?, calendarID: String, alarms: [TimeInterval], recurrence: RecurrenceRule?, priority: Int? = nil, isTask: Bool = false) async throws {
        guard let calendar = availableCalendars.first(where: { $0.calendarIdentifier == calendarID }) else { throw EventKitError.fetchFailed("Calendar not found") }
        let colorHex = calendar.cgColor.toHexString() ?? "#007AFF"
        let source: EventSource = isTask ? .reminder : .eventKit
        let summary = recurrence?.summary ?? ""
        let appEvent = AppEvent(title: title, startDate: startDate, endDate: endDate, isAllDay: isAllDay, location: location, notes: notes, hasAlarms: !alarms.isEmpty, source: source, calendarID: calendarID, colorHex: colorHex, recurrenceSummary: summary, priority: priority)
        if isTask {
            try await eventKitManager.createReminder(appEvent: appEvent, alarms: alarms)
        } else {
            try await eventKitManager.createEvent(appEvent: appEvent, alarms: alarms, recurrence: recurrence)
        }
        await refreshData()
    }

    public func toggleTaskCompleted(_ task: AppEvent) {
        // Update notes with completed flag
        eventKitManager.completeReminder(id: task.id)
        Task { await refreshData() }
    }

    public func deleteReminder(at offsets: IndexSet) {
        for index in offsets {
            eventKitManager.deleteReminder(id: allReminders[index].id)
        }
        Task { await refreshData() }
    }

    public func remindersForDay(_ date: Date) -> [AppEvent] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return allReminders.filter { $0.startDate >= startOfDay && $0.startDate < endOfDay }
    }

    var dateRangeArray: [Date] {
        var dates: [Date] = []
        let cal = Calendar.current
        var current = cal.startOfDay(for: currentViewRange.start)
        while current <= currentViewRange.end {
            dates.append(current)
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }
}

// Recurrence helper
public struct RecurrenceRule: Identifiable, Codable {
    public let id = UUID()
    let frequency: Frequency
    let interval: Int
    var summary: String { "Every \(interval) \(frequency.rawValue)" }

    enum Frequency: String, CaseIterable, Codable { case daily, weekly, monthly, yearly }
}
