import SwiftUI
import Combine
import EventKit

@MainActor
public class CalendarViewModel: ObservableObject {
    @Published var groupedEvents: [Date: [AppEvent]] = [:]
    @Published var availableCalendars: [EKCalendar] = []
    @Published var selectedView: String = "month"
    @Published var daysToDisplay: Int = 7
    @Published var searchText: String = ""
    @Published var isSidebarOpen: Bool = false
    
    let eventKitManager = EventKitManager()
    
    public init() {
        Task { await refreshData() }
    }
    
    public func refreshData() async {
        let start = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let end = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        
        do {
            try await eventKitManager.requestAccess()
            let items = try await eventKitManager.fetchItems(from: start, to: end)
            
            // Filter by Search
            let filtered = searchText.isEmpty ? items : items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            
            var dict: [Date: [AppEvent]] = [:]
            for item in filtered {
                let day = Calendar.current.startOfDay(for: item.startDate)
                dict[day, default: []].append(item)
            }
            self.groupedEvents = dict
            self.availableCalendars = eventKitManager.store.calendars(for: .event)
        } catch { print(error) }
    }
}
