import Foundation
import SwiftUI
import Combine
import EventKit

@MainActor
public class CalendarViewModel: ObservableObject {
    @Published public var groupedEvents: [Date: [AppEvent]] = [:]
    @Published public var reminders: [AppReminder] = []
    
    @Published public var availableCalendars: [EKCalendar] = []
    @Published public var availableReminderLists: [EKCalendar] = []
    @Published public var visibleCalendarIDs: Set<String> = []
    @Published public var visibleReminderListIDs: Set<String> = []
    
    @Published public var isLoading: Bool = false
    @Published public var anchorDate: Date = Date()
    @Published public var searchText: String = ""
    @Published public var selectedView: String = "month"
    @Published public var daysToDisplay: Int = 7
    
    @Published public var coreHourStart: Int = 8
    @Published public var coreHourEnd: Int = 18
    @Published public var eventOpacity: Double = 0.2
    @Published public var themeColorHex: String = "#007AFF"

    public var currentViewRange: (start: Date, end: Date)
    public let eventKitManager: EventKitManager
    private var cancellables = Set<AnyCancellable>()

    public init(eventKitManager: EventKitManager? = nil) {
        self.eventKitManager = eventKitManager ?? EventKitManager()
        let cal = Calendar.current
        self.currentViewRange = (cal.date(byAdding: .month, value: -3, to: Date())!, cal.date(byAdding: .month, value: 6, to: Date())!)
        
        loadPreferences()
        
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in Task { await self?.refreshData() } }.store(in: &cancellables)
    }

    public func requestAccessAndFetch() async {
        do {
            try await eventKitManager.requestCalendarAccess()
            try await eventKitManager.requestReminderAccess()
            self.availableCalendars = eventKitManager.fetchActiveCalendars()
            self.availableReminderLists = eventKitManager.fetchActiveReminderLists()
            
            if visibleCalendarIDs.isEmpty { self.visibleCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier }) }
            if visibleReminderListIDs.isEmpty { self.visibleReminderListIDs = Set(availableReminderLists.map { $0.calendarIdentifier }) }
            
            await refreshData()
        } catch { print("Auth Failed: \(error)") }
    }

    public func refreshData() async {
        guard eventKitManager.isAuthorized else { return }
        isLoading = true
        
        let targetCals = availableCalendars.filter { visibleCalendarIDs.contains($0.calendarIdentifier) }
        let targetLists = availableReminderLists.filter { visibleReminderListIDs.contains($0.calendarIdentifier) }
        
        do {
            let events = try await eventKitManager.fetchEvents(from: currentViewRange.start, to: currentViewRange.end, in: targetCals)
            let rawReminders = try await eventKitManager.fetchReminders(in: targetLists)
            
            var dict: [Date: [AppEvent]] = [:]
            for e in events {
                var currentDay = Calendar.current.startOfDay(for: e.startDate)
                let endOfDay = Calendar.current.startOfDay(for: e.endDate)
                while currentDay <= endOfDay {
                    dict[currentDay, default: []].append(e)
                    currentDay = Calendar.current.date(byAdding: .day, value: 1, to: currentDay)!
                }
            }
            for (date, evs) in dict { dict[date] = evs.sorted { $0.isAllDay && !$1.isAllDay } }
            self.groupedEvents = dict
            self.reminders = rawReminders
        } catch { print("Fetch failed: \(error)") }
        isLoading = false
    }

    public func toggleCalendarVisibility(calendarID: String) async {
        if visibleCalendarIDs.contains(calendarID) { visibleCalendarIDs.remove(calendarID) } else { visibleCalendarIDs.insert(calendarID) }
        await refreshData()
    }
    
    public func toggleReminderListVisibility(listID: String) async {
        if visibleReminderListIDs.contains(listID) { visibleReminderListIDs.remove(listID) } else { visibleReminderListIDs.insert(listID) }
        await refreshData()
    }
    
    public func toggleReminderCompleted(_ reminder: AppReminder) async {
        do { try await eventKitManager.toggleTaskCompletion(reminder); await refreshData() } catch { print(error) }
    }
    
    public var dateRangeArray: [Date] {
        var dates: [Date] = []
        var current = Calendar.current.startOfDay(for: anchorDate)
        let end = Calendar.current.date(byAdding: .day, value: 60, to: current)!
        while current <= end { dates.append(current); current = Calendar.current.date(byAdding: .day, value: 1, to: current)! }
        return dates
    }
    
    public var filteredReminders: [AppReminder] {
        searchText.isEmpty ? reminders : reminders.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadPreferences() {
        let d = UserDefaults.standard
        coreHourStart = d.integer(forKey: "coreHourStart") == 0 ? 8 : d.integer(forKey: "coreHourStart")
        coreHourEnd = d.integer(forKey: "coreHourEnd") == 0 ? 18 : d.integer(forKey: "coreHourEnd")
        eventOpacity = d.double(forKey: "eventOpacity") == 0 ? 0.2 : d.double(forKey: "eventOpacity")
    }

    public func updateCoreHours(start: Int, end: Int) {
        coreHourStart = max(0, min(23, start)); coreHourEnd = max(coreHourStart + 1, min(24, end))
        UserDefaults.standard.set(coreHourStart, forKey: "coreHourStart")
        UserDefaults.standard.set(coreHourEnd, forKey: "coreHourEnd")
    }
}
