import Foundation
import SwiftUI
import Combine
import EventKit

// MARK: - Calendar ViewModel
@MainActor
public class CalendarViewModel: ObservableObject {
    
    // MARK: Published UI State
    @Published public var groupedEvents: [Date: [AppEvent]] = [:]
    @Published public var availableCalendars: [EKCalendar] = []
    @Published public var visibleCalendarIDs: Set<String> = []
    @Published public var isLoading: Bool = false
    
    // MARK: Internal State
    private let eventKitManager: EventKitManager
    private var cancellables = Set<AnyCancellable>()
    
    public var currentViewRange: (start: Date, end: Date)
    
    // FIXED: Changed the init to handle the EventKitManager safely on the MainActor
    @MainActor
    public init(eventKitManager: EventKitManager? = nil) {
        // If no manager is provided, we create one here safely on the MainActor
        self.eventKitManager = eventKitManager ?? EventKitManager()
        
        let today = Date()
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        let end = calendar.date(byAdding: .month, value: 3, to: today) ?? today
        self.currentViewRange = (start, end)
        
        setupObservers()
    }
    
    // MARK: - Setup & Observers
    private func setupObservers() {
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in
                Task { await self?.refreshData() }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in
                Task { await self?.refreshData() }
            }
            .store(in: &cancellables)
    }
    
    public func requestAccessAndFetch() async {
        do {
            try await eventKitManager.requestCalendarAccess()
            loadCalendars()
            await refreshData()
        } catch {
            print("EventKit Authorization Failed: \(error.localizedDescription)")
        }
    }
    
    private func loadCalendars() {
        let calendars = eventKitManager.fetchActiveCalendars()
        self.availableCalendars = calendars
        
        if visibleCalendarIDs.isEmpty {
            self.visibleCalendarIDs = Set(calendars.map { $0.calendarIdentifier })
        }
    }
    
    public func toggleCalendarVisibility(calendarID: String) async {
        if visibleCalendarIDs.contains(calendarID) {
            visibleCalendarIDs.remove(calendarID)
        } else {
            visibleCalendarIDs.insert(calendarID)
        }
        await refreshData()
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
            print("Failed to fetch event data: \(error.localizedDescription)")
        }
        
        isLoading = false
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
}
