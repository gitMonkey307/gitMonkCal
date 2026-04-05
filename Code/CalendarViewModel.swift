import Foundation
import SwiftUI
import Combine
import EventKit

// MARK: - Calendar ViewModel
/// The central brain bridging the EventKitManager's raw data to our SwiftUI UI.
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
    
    /// The current date range loaded into memory (e.g., 1 month past, 3 months forward)
    public var currentViewRange: (start: Date, end: Date)
    
    public init(eventKitManager: EventKitManager = EventKitManager()) {
        self.eventKitManager = eventKitManager
        
        // Define an initial memory-safe loading window
        let today = Date()
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        let end = calendar.date(byAdding: .month, value: 3, to: today) ?? today
        self.currentViewRange = (start, end)
        
        setupObservers()
    }
    
    // MARK: - Setup & Observers
    private func setupObservers() {
        // 1. Listen for timezone changes or midnight rollovers
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in
                Task { await self?.refreshData() }
            }
            .store(in: &cancellables)
        
        // 2. Listen for external database changes (e.g., Apple Calendar app syncs in the background)
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in
                Task { await self?.refreshData() }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Orchestration
    
    /// Requests permissions and executes the initial data pull.
    public func requestAccessAndFetch() async {
        do {
            try await eventKitManager.requestCalendarAccess()
            loadCalendars()
            await refreshData()
        } catch {
            print("EventKit Authorization Failed: \(error.localizedDescription)")
            // In a production app, we would publish this error to an @Published var to show an alert
        }
    }
    
    /// Pulls the available lists and defaults them to visible.
    private func loadCalendars() {
        let calendars = eventKitManager.fetchActiveCalendars()
        self.availableCalendars = calendars
        
        // If this is the first load, toggle all active calendars on
        if visibleCalendarIDs.isEmpty {
            self.visibleCalendarIDs = Set(calendars.map { $0.calendarIdentifier })
        }
    }
    
    /// Toggles a specific calendar's visibility and triggers a UI refresh.
    public func toggleCalendarVisibility(calendarID: String) async {
        if visibleCalendarIDs.contains(calendarID) {
            visibleCalendarIDs.remove(calendarID)
        } else {
            visibleCalendarIDs.insert(calendarID)
        }
        
        // Immediately reload the events array with the new filter
        await refreshData()
    }
    
    /// Fetches raw events and passes them to the grouping engine.
    public func refreshData() async {
        guard eventKitManager.isAuthorized else { return }
        
        isLoading = true
        
        // Filter Apple's raw EKCalendars down to what the user actually wants to see
        let targetCalendars = availableCalendars.filter { visibleCalendarIDs.contains($0.calendarIdentifier) }
        
        do {
            let rawEvents = try await eventKitManager.fetchEvents(
                from: currentViewRange.start,
                to: currentViewRange.end,
                in: targetCalendars
            )
            
            // Execute the heavy grouping logic and publish to the UI
            self.groupedEvents = groupEventsByDay(rawEvents)
        } catch {
            print("Failed to fetch event data: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Grouping Engine
    
    /// Converts a flat array of events into a dictionary mapped to the start of each day.
    /// Crucially handles multi-day events by duplicating their references across spanning days.
    private func groupEventsByDay(_ events: [AppEvent]) -> [Date: [AppEvent]] {
        let calendar = Calendar.current
        var dictionary: [Date: [AppEvent]] = [:]
        
        for event in events {
            let startOfDay = calendar.startOfDay(for: event.startDate)
            let endOfDay = calendar.startOfDay(for: event.endDate)
            
            var currentDay = startOfDay
            
            // Replicate BC2's multi-day behavior: Drop the event into every day it touches
            while currentDay <= endOfDay {
                dictionary[currentDay, default: []].append(event)
                currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
            }
        }
        
        // Sort the nested arrays so the UI is perfectly ordered
        for (date, dailyEvents) in dictionary {
            dictionary[date] = dailyEvents.sorted { lhs, rhs in
                // All-day events always float to the top
                if lhs.isAllDay && !rhs.isAllDay { return true }
                if !lhs.isAllDay && rhs.isAllDay { return false }
                // Otherwise, sort chronologically
                return lhs.startDate < rhs.startDate
            }
        }
        
        return dictionary
    }
}