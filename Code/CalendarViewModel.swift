import Foundation
import SwiftUI
import Combine
import EventKit

@MainActor
public class CalendarViewModel: ObservableObject {
    @Published public var groupedEvents: [Date: [AppEvent]] = [:]
    @Published public var reminders: [AppReminder] = []
    @Published public var templates: [EventTemplate] = []
    @Published public var searchHistory: [String] = []
    @Published public var recentLocations: [String] = []
    
    @Published public var availableCalendars: [EKCalendar] = []
    @Published public var availableReminderLists: [EKCalendar] = []
    @Published public var visibleCalendarIDs: Set<String> = []
    @Published public var visibleReminderListIDs: Set<String> = []
    
    @Published public var isLoading: Bool = false
    @Published public var anchorDate: Date = Date()
    @Published public var searchText: String = ""
    @Published public var selectedView: String? = "month"
    @Published public var agendaFilter: String = "all"
    @Published public var daysToDisplay: Int = 7
    
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
    @Published public var isHighDensity: Bool = false
    @Published public var coreHourStart: Int = 8
    @Published public var coreHourEnd: Int = 18

    private var cancellables = Set<AnyCancellable>()
    public let eventKitManager = EventKitManager()
    public var currentViewRange: (start: Date, end: Date)

    public var filteredReminders: [AppReminder] {
        if searchText.isEmpty { return reminders }
        return reminders.filter { $0.title.localizedCaseInsensitiveContains(searchText) || ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false) }
    }

    public var dateRangeArray: [Date] {
        var dates: [Date] = []
        var current = Foundation.Calendar.current.startOfDay(for: anchorDate)
        let end = Foundation.Calendar.current.date(byAdding: .day, value: 60, to: current)!
        while current <= end { dates.append(current); current = Foundation.Calendar.current.date(byAdding: .day, value: 1, to: current)! }
        return dates
    }

    public init() {
        let cal = Foundation.Calendar.current
        self.currentViewRange = (cal.date(byAdding: .month, value: -3, to: Date())!, cal.date(byAdding: .month, value: 6, to: Date())!)
        loadPreferences()
        
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in Task { await self?.refreshData() } }.store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in self?.objectWillChange.send(); Task { await self?.refreshData() } }.store(in: &cancellables)
    }

    public func handleDeepLink(url: URL) {
        guard url.scheme == "gitmonkcal", url.host == "event", let eventID = url.pathComponents.last else { return }
        for eventList in groupedEvents.values {
            if let target = eventList.first(where: { $0.id == eventID }) { self.editingEvent = target; return }
        }
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
                var currentDay = Foundation.Calendar.current.startOfDay(for: e.startDate)
                let endOfDay = Foundation.Calendar.current.startOfDay(for: e.endDate)
                var loopCount = 0
                while currentDay <= endOfDay && loopCount < 366 {
                    dict[currentDay, default: []].append(e)
                    currentDay = Foundation.Calendar.current.date(byAdding: .day, value: 1, to: currentDay)!
                    loopCount += 1
                }
            }
            self.groupedEvents = dict; self.reminders = rawReminders
        } catch { print("gitMonk sync error") }
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
        } catch { print("Auth fail") }
    }

    public func toggleReminderCompleted(_ reminder: AppReminder) async {
        try? await eventKitManager.toggleTaskCompletion(reminder)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        await refreshData()
    }

    public func deleteEvent(_ event: AppEvent) { try? eventKitManager.deleteEvent(identifier: event.id); Task { await refreshData() } }
    public func deleteTask(_ task: AppReminder) { try? eventKitManager.deleteTask(identifier: task.id); Task { await refreshData() } }
    public func jumpToToday() { anchorDate = Date() }
    
    public func toggleCalendarVisibility(calendarID: String) async {
        if visibleCalendarIDs.contains(calendarID) { visibleCalendarIDs.remove(calendarID) } else { visibleCalendarIDs.insert(calendarID) }
        await refreshData()
    }
    
    public func toggleReminderListVisibility(listID: String) async {
        if visibleReminderListIDs.contains(listID) { visibleReminderListIDs.remove(listID) } else { visibleReminderListIDs.insert(listID) }
        await refreshData()
    }

    private func loadPreferences() {
        let d = UserDefaults.standard
        themeColorHex = d.string(forKey: "themeColorHex") ?? "#007AFF"
        hideCompletedTasks = d.bool(forKey: "hideCompletedTasks")
        isHighDensity = d.bool(forKey: "isHighDensity")
        searchHistory = d.stringArray(forKey: "search_history") ?? []
        recentLocations = d.stringArray(forKey: "recent_locations") ?? []
        defaultDuration = d.integer(forKey: "defaultDuration") == 0 ? 60 : d.integer(forKey: "defaultDuration")
        firstDayOfWeek = d.integer(forKey: "firstDayOfWeek") == 0 ? 1 : d.integer(forKey: "firstDayOfWeek")
        eventOpacity = d.double(forKey: "eventOpacity") == 0 ? 0.2 : d.double(forKey: "eventOpacity")
        coreHourStart = d.integer(forKey: "coreHourStart") == 0 ? 8 : d.integer(forKey: "coreHourStart")
        coreHourEnd = d.integer(forKey: "coreHourEnd") == 0 ? 18 : d.integer(forKey: "coreHourEnd")
        if let data = d.data(forKey: "saved_templates"), let decoded = try? JSONDecoder().decode([EventTemplate].self, from: data) { templates = decoded }
    }

    public func updateSettings(hideTasks: Bool, duration: Int, themeHex: String, firstDay: Int, density: Bool) {
        hideCompletedTasks = hideTasks; defaultDuration = duration; themeColorHex = themeHex; firstDayOfWeek = firstDay; isHighDensity = density
        let d = UserDefaults.standard
        d.set(hideTasks, forKey: "hideCompletedTasks"); d.set(duration, forKey: "defaultDuration")
        d.set(themeHex, forKey: "themeColorHex"); d.set(firstDay, forKey: "firstDayOfWeek"); d.set(density, forKey: "isHighDensity")
    }

    public func updateCoreHours(start: Int, end: Int) {
        coreHourStart = max(0, min(23, start)); coreHourEnd = max(coreHourStart + 1, min(24, end))
        UserDefaults.standard.set(coreHourStart, forKey: "coreHourStart"); UserDefaults.standard.set(coreHourEnd, forKey: "coreHourEnd")
    }
    
    public func saveLocation(_ loc: String) { guard !loc.isEmpty else { return }; var cur = recentLocations; cur.removeAll { $0 == loc }; cur.insert(loc, at: 0); recentLocations = Array(cur.prefix(5)); UserDefaults.standard.set(recentLocations, forKey: "recent_locations") }
    public func saveTemplate(_ temp: EventTemplate) { templates.append(temp); if let encoded = try? JSONEncoder().encode(templates) { UserDefaults.standard.set(encoded, forKey: "saved_templates") } }
    public func deleteTemplate(at offsets: IndexSet) { templates.remove(atOffsets: offsets); if let encoded = try? JSONEncoder().encode(templates) { UserDefaults.standard.set(encoded, forKey: "saved_templates") } }
    public func addToSearchHistory(_ term: String) { guard !term.isEmpty else { return }; var cur = searchHistory; cur.removeAll { $0 == term }; cur.insert(term, at: 0); searchHistory = Array(cur.prefix(3)); UserDefaults.standard.set(searchHistory, forKey: "search_history") }
    
    public func moveItemToTomorrow(_ item: UnifiedAgendaItem) {
        let tomorrow = Foundation.Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        Task {
            switch item {
            case .event(let e): try? await eventKitManager.saveEvent(id: nil, title: e.title, start: tomorrow, end: tomorrow.addingTimeInterval(3600), isAllDay: e.isAllDay, location: e.location, notes: e.notes, calendarID: e.calendarID, alarms: e.alarms, recurrenceType: e.recurrence, customColorHex: e.customColorHex)
            case .task(let t): try? await eventKitManager.saveTask(id: nil, title: t.title, dueDate: tomorrow, notes: t.notes, listID: t.listID, priority: t.priority)
            }
            await refreshData()
        }
    }
}
