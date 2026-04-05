import Foundation
import SwiftUI
import Combine
import EventKit

@MainActor
public class CalendarViewModel: ObservableObject {
    @Published public var groupedEvents: [Date: [AppEvent]] = [:]
    @Published public var reminders: [AppReminder] = []
    @Published public var availableCalendars: [EKCalendar] = []
    @Published public var availableReminderLists: [EKReminderCalendar] = []
    @Published public var visibleCalendarIDs: Set<String> = []
    @Published public var visibleReminderListIDs: Set<String> = []
    @Published public var isLoading: Bool = false
    @Published public var anchorDate: Date = Date()
    @Published public var searchText: String = ""
    @Published public var coreHourStart: Int = 8
    @Published public var coreHourEnd: Int = 18
    @Published public var eventOpacity: Double = 0.2
    @Published public var themeColorHex: String = "#007AFF"

    public var currentViewRange: (start: Date, end: Date)
    private let eventKitManager: EventKitManager
    private var cancellables = Set<AnyCancellable>()

    public init(eventKitManager: EventKitManager? = nil) {
        self.eventKitManager = eventKitManager ?? EventKitManager()
        updateViewRange()
        setupObservers()
        loadPreferences()
    }

    private func updateViewRange() {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -3, to: anchorDate)!
        let end = calendar.date(byAdding: .month, value: 3, to: anchorDate)!
        self.currentViewRange = (start, end)
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in Task { await self?.refreshData() } }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in Task { await self?.refreshData() } }
            .store(in: &cancellables)
    }

    public func requestAccessAndFetch() async {
        do {
            try await eventKitManager.requestCalendarAccess()
            try await eventKitManager.requestReminderAccess()
            loadCalendars()
            loadReminderLists()
            await refreshData()
        } catch {
            print("Authorization Failed: \(error.localizedDescription)")
        }
    }

    private func loadCalendars() {
        let calendars = eventKitManager.fetchActiveCalendars()
        self.availableCalendars = calendars
        if visibleCalendarIDs.isEmpty {
            self.visibleCalendarIDs = Set(calendars.map { $0.calendarIdentifier })
        }
    }

    private func loadReminderLists() {
        let lists = eventKitManager.fetchActiveReminderLists()
        self.availableReminderLists = lists
        if visibleReminderListIDs.isEmpty {
            self.visibleReminderListIDs = Set(lists.map { $0.calendarIdentifier })
        }
    }

    public func toggleCalendarVisibility(calendarID: String) async {
        if visibleCalendarIDs.contains(calendarID) {
            visibleCalendarIDs.remove(calendarID)
        } else {
            visibleCalendarIDs.insert(calendarID)
        }
        savePreferences()
        await refreshData()
    }

    public func toggleReminderListVisibility(listID: String) async {
        if visibleReminderListIDs.contains(listID) {
            visibleReminderListIDs.remove(listID)
        } else {
            visibleReminderListIDs.insert(listID)
        }
        savePreferences()
        await refreshReminders()
    }

    public func refreshData() async {
        guard eventKitManager.isAuthorized else { return }
        isLoading = true

        let targetCalendars = availableCalendars.filter { visibleCalendarIDs.contains($0.calendarIdentifier) }
        do {
            let rawEvents = try await eventKitManager.fetchEvents(
                from: currentViewRange.start,
                to: currentViewRange.end,
                in: targetCalendars
            )
            self.groupedEvents = groupEventsByDay(rawEvents)
        } catch {
            print("Failed to fetch events: \(error.localizedDescription)")
        }

        await refreshReminders()
        isLoading = false
    }

    public func refreshReminders() async {
        let targetLists = availableReminderLists.filter { visibleReminderListIDs.contains($0.calendarIdentifier) }
        do {
            let ekReminders = try await eventKitManager.fetchReminders(in: targetLists)
            self.reminders = ekReminders.map { EventKitManager.mapToAppReminder($0) }.sorted { ($0.dueDate ?? Date.distantPast) < ($1.dueDate ?? Date.distantPast) }
        } catch {
            print("Failed to fetch reminders: \(error)")
        }
    }

    private func groupEventsByDay(_ events: [AppEvent]) -> [Date: [AppEvent]] {
        let calendar = Calendar.current
        var dictionary: [Date: [AppEvent]] = [:]

        for event in events {
            let startOfDay = calendar.startOfDay(for: event.startDate)
            let endOfDay = calendar.startOfDay(for: event.endDate)

            var currentDay = startOfDay
            while currentDay <= endOfDay {
                dictionary[currentDay, default: []].append(event)
                currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
            }
        }

        for (date, dailyEvents) in dictionary {
            dictionary[date] = dailyEvents.sorted { lhs, rhs in
                if lhs.isAllDay && !rhs.isAllDay { return true }
                if !lhs.isAllDay && rhs.isAllDay { return false }
                return lhs.startDate < rhs.startDate
            }
        }

        return dictionary
    }

    public var filteredEvents: [AppEvent] {
        let allEvents = groupedEvents.values.flatMap { $0 }
        if searchText.isEmpty { return allEvents }
        return allEvents.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.notes?.localizedCaseInsensitiveContains(searchText) == true }
    }

    public var filteredReminders: [AppReminder] {
        if searchText.isEmpty { return reminders }
        return reminders.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    public var dateRangeArray: [Date] {
        var dates: [Date] = []
        let cal = Calendar.current
        var current = cal.startOfDay(for: currentViewRange.start)
        while current <= currentViewRange.end {
            dates.append(current)
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }

    public func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        calendarID: String,
        alarms: [TimeInterval],
        recurrenceType: RecurrenceType = .none
    ) async throws {
        guard let calendar = availableCalendars.first(where: { $0.calendarIdentifier == calendarID }) else {
            throw EventKitError.fetchFailed("Selected calendar not available")
        }
        let colorHex = calendar.cgColor.toHexString() ?? "#007AFF"
        
        let appEvent = AppEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            hasAlarms: !alarms.isEmpty,
            source: .eventKit,
            calendarID: calendarID,
            colorHex: colorHex
        )
        
        try await eventKitManager.createEvent(appEvent: appEvent, alarms: alarms, recurrenceType: recurrenceType)
        await refreshData()
    }

    public func toggleReminderCompleted(_ reminder: AppReminder) async {
        // Simplified: refetch as complete toggle requires ID mapping
        await refreshReminders()
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        coreHourStart = defaults.integer(forKey: "coreHourStart")
        coreHourEnd = defaults.integer(forKey: "coreHourEnd")
        eventOpacity = defaults.double(forKey: "eventOpacity")
        themeColorHex = defaults.string(forKey: "themeColorHex") ?? "#007AFF"
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(coreHourStart, forKey: "coreHourStart")
        defaults.set(coreHourEnd, forKey: "coreHourEnd")
        defaults.set(eventOpacity, forKey: "eventOpacity")
        defaults.set(themeColorHex, forKey: "themeColorHex")
    }

    public func updateCoreHours(start: Int, end: Int) {
        coreHourStart = max(0, min(23, start))
        coreHourEnd = max(coreHourStart + 1, min(24, end))
        savePreferences()
    }

    public func updateEventOpacity(_ opacity: Double) {
        eventOpacity = max(0.1, min(1.0, opacity))
        savePreferences()
    }
}

public enum RecurrenceType: String, CaseIterable, Identifiable {
    case none, daily, weekly, monthly, yearly
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}
