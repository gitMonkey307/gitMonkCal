import Foundation
import SwiftUI
import Combine
import EventKit

@MainActor
public class CalendarViewModel: ObservableObject {
    @Published public var groupedEvents: [Date: [AppEvent]] = [:]
    @Published public var reminders: [AppReminder] = []
    @Published public var templates: [EventTemplate] = [] // Feature: Templates
    
    @Published public var availableCalendars: [EKCalendar] = []
    @Published public var availableReminderLists: [EKCalendar] = []
    @Published public var visibleCalendarIDs: Set<String> = []
    @Published public var visibleReminderListIDs: Set<String> = []
    
    @Published public var isLoading: Bool = false
    @Published public var anchorDate: Date = Date()
    @Published public var searchText: String = ""
    @Published public var selectedView: String = "month"
    @Published public var agendaFilter: String = "all" // "all", "events", "tasks"
    
    // Global Settings & Routing
    @Published public var isAddingNew: Bool = false
    @Published public var targetDateForNewItem: Date? = nil
    @Published public var editingEvent: AppEvent? = nil
    @Published public var editingTask: AppReminder? = nil
    @Published public var eventToDuplicate: AppEvent? = nil
    @Published public var showDatePicker: Bool = false
    @Published public var themeColorHex: String = "#007AFF"
    @Published public var hideCompletedTasks: Bool = false
    @Published public var defaultDuration: Int = 60
    @Published public var firstDayOfWeek: Int = 1
    @Published public var eventOpacity: Double = 0.2
    @Published public var coreHourStart: Int = 8
    @Published public var coreHourEnd: Int = 18

    public var currentViewRange: (start: Date, end: Date)
    public let eventKitManager: EventKitManager
    private var cancellables = Set<AnyCancellable>()

    public var filteredReminders: [AppReminder] {
        searchText.isEmpty ? reminders : reminders.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    public init(eventKitManager: EventKitManager? = nil) {
        self.eventKitManager = eventKitManager ?? EventKitManager()
        let cal = Calendar.current
        self.currentViewRange = (cal.date(byAdding: .month, value: -3, to: Date())!, cal.date(byAdding: .month, value: 6, to: Date())!)
        loadPreferences()
        
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in Task { await self?.refreshData() } }.store(in: &cancellables)
    }

    // MARK: - Template Management
    public func saveTemplate(_ template: EventTemplate) {
        templates.append(template)
        if let encoded = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(encoded, forKey: "saved_templates")
        }
    }
    
    public func deleteTemplate(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        if let encoded = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(encoded, forKey: "saved_templates")
        }
    }

    // MARK: - Refresh Data
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
        } catch { print(error) }
        isLoading = false
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
        } catch { print(error) }
    }

    public func toggleReminderCompleted(_ reminder: AppReminder) async {
        do { 
            try await eventKitManager.toggleTaskCompletion(reminder)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await refreshData() 
        } catch { print(error) }
    }
    
    public func deleteEvent(_ event: AppEvent) { try? eventKitManager.deleteEvent(identifier: event.id); Task { await refreshData() } }
    public func deleteTask(_ task: AppReminder) { try? eventKitManager.deleteTask(identifier: task.id); Task { await refreshData() } }
    public func jumpToToday() { anchorDate = Date() }
    
    public func toggleCalendarVisibility(calendarID: String) async {
        if visibleCalendarIDs.contains(calendarID) { visibleCalendarIDs.remove(calendarID) } else { visibleCalendarIDs.insert(calendarID) }
        await refreshData()
    }
    
    private func loadPreferences() {
        let d = UserDefaults.standard
        themeColorHex = d.string(forKey: "themeColorHex") ?? "#007AFF"
        hideCompletedTasks = d.bool(forKey: "hideCompletedTasks")
        defaultDuration = d.integer(forKey: "defaultDuration") == 0 ? 60 : d.integer(forKey: "defaultDuration")
        firstDayOfWeek = d.integer(forKey: "firstDayOfWeek") == 0 ? 1 : d.integer(forKey: "firstDayOfWeek")
        eventOpacity = d.double(forKey: "eventOpacity") == 0 ? 0.2 : d.double(forKey: "eventOpacity")
        
        if let data = d.data(forKey: "saved_templates"), let decoded = try? JSONDecoder().decode([EventTemplate].self, from: data) {
            templates = decoded
        }
    }
    
    public func updateSettings(hideTasks: Bool, duration: Int, themeHex: String, firstDay: Int) {
        hideCompletedTasks = hideTasks; defaultDuration = duration; themeColorHex = themeHex; firstDayOfWeek = firstDay
        UserDefaults.standard.set(hideTasks, forKey: "hideCompletedTasks")
        UserDefaults.standard.set(duration, forKey: "defaultDuration")
        UserDefaults.standard.set(themeHex, forKey: "themeColorHex")
        UserDefaults.standard.set(firstDay, forKey: "firstDayOfWeek")
    }
    
    public func updateCoreHours(start: Int, end: Int) {
        coreHourStart = max(0, min(23, start)); coreHourEnd = max(coreHourStart + 1, min(24, end))
        UserDefaults.standard.set(coreHourStart, forKey: "coreHourStart"); UserDefaults.standard.set(coreHourEnd, forKey: "coreHourEnd")
    }
}
