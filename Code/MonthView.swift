import SwiftUI

// MARK: - Dummy Data Generator
/// A quick extension to generate mock data so we can see the density immediately.
extension AppEvent {
    public static var dummyData: [Date: [AppEvent]] {
        let calendar = Calendar.current
        let today = Date()
        var events: [Date: [AppEvent]] = [:]
        
        // Let's create a very dense day to test text-wrapping
        let denseDay = calendar.date(byAdding: .day, value: 2, to: today)!
        events[calendar.startOfDay(for: denseDay)] = [
            AppEvent(title: "Morning Sync with Team", startDate: today, endDate: today, calendarID: "1", colorHex: "#FF3B30"), // iOS Red
            AppEvent(title: "Project Review & Code Audit", startDate: today, endDate: today, calendarID: "1", colorHex: "#007AFF"), // iOS Blue
            AppEvent(title: "Lunch", startDate: today, endDate: today, calendarID: "2", colorHex: "#34C759") // iOS Green
        ]
        
        // A standard single-event day
        let normalDay = calendar.date(byAdding: .day, value: 5, to: today)!
        events[calendar.startOfDay(for: normalDay)] = [
            AppEvent(title: "Dentist Appointment", startDate: today, endDate: today, calendarID: "1", colorHex: "#AF52DE") // iOS Purple
        ]
        
        return events
    }
}

// MARK: - Core Month View
public struct MonthView: View {
    
    /// In a real scenario, this comes from our CalendarViewModel
    let groupedEvents: [Date: [AppEvent]]
    
    /// 7 flexible columns for the days of the week, zero spacing to enforce the BC2 edge-to-edge feel.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    
    // Generates a mock 35-day grid (5 weeks) for current month visualization
    private var mockDays: [Date] {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else { return [] }
        return (0..<35).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfMonth) }
    }
    
    public init(groupedEvents: [Date: [AppEvent]] = AppEvent.dummyData) {
        self.groupedEvents = groupedEvents
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Day of Week Header
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(DesignSystem.Typography.timeLabel)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Layout.densePadding)
                        .border(DesignSystem.Aesthetics.gridLine, width: 0.25)
                }
            }
            
            // The Dense Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(mockDays, id: \.self) { date in
                        let startOfDay = Calendar.current.startOfDay(for: date)
                        let eventsForDay = groupedEvents[startOfDay] ?? []
                        
                        MonthDayCell(date: date, events: eventsForDay)
                    }
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Individual Day Cell
struct MonthDayCell: View {
    let date: Date
    let events: [AppEvent]
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Day Number (Top Right, iOS style)
            Text(dayNumber)
                .font(DesignSystem.Typography.header.weight(.medium))
                // Differentiate today vs other days
                .foregroundColor(Calendar.current.isDateInToday(date) ? .white : .primary)
                .padding(4)
                .background(Calendar.current.isDateInToday(date) ? Color.blue : Color.clear)
                .clipShape(Circle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 2)
                .padding(.trailing, 2)
            
            // Event Pills
            ForEach(events) { event in
                EventPill(event: event)
            }
            
            Spacer(minLength: 0)
        }
        // Force an edge-to-edge square/rectangle
        .frame(minHeight: 100, maxHeight: .infinity, alignment: .top)
        // Replicating the rigid BC2 grid using iOS subtle dividers
        .border(DesignSystem.Aesthetics.gridLine, width: 0.25)
        .contentShape(Rectangle()) // Ensures the whole cell is tappable/long-pressable
        
        // Native iOS Context Menu replacing Android long-press overlays
        .contextMenu {
            Button {
                // Action: Add new event to this date
            } label: {
                Label("New Event", systemImage: "calendar.badge.plus")
            }
            
            Button {
                // Action: Jump to day view
            } label: {
                Label("Go to Day", systemImage: "arrow.right.circle")
            }
            
            Divider()
            
            Button(role: .destructive) {
                // Action: Clear day
            } label: {
                Label("Clear All", systemImage: "trash")
            }
        }
    }
}

// MARK: - Reusable Event Pill
struct EventPill: View {
    let event: AppEvent
    
    var body: some View {
        Text(event.title)
            .font(DesignSystem.Typography.eventPill)
            .lineLimit(2) // Allows text-wrapping for dense days, exactly like BC2
            .multilineTextAlignment(.leading)
            .padding(.horizontal, DesignSystem.Layout.microPadding)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            // iOS native styling: colored background with slight opacity, bold foreground
            .background(event.displayColor.opacity(0.2))
            .foregroundColor(event.displayColor)
            .cornerRadius(DesignSystem.Aesthetics.pillRadius)
            .padding(.horizontal, 1) // Keeps it barely off the grid lines
    }
}

// MARK: - Preview
struct MonthView_Previews: PreviewProvider {
    static var previews: some View {
        MonthView()
    }
}
