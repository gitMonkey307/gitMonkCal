import WidgetKit
import SwiftUI
import EventKit

// MARK: - Timeline Provider
/// The engine that dictates when the widget updates. 
/// Widgets are severely memory-limited, so we must be efficient.
struct AgendaProvider: TimelineProvider {
    
    // We instantiate a lightweight instance of our manager specifically for the widget
    let eventManager = EventKitManager()
    
    func placeholder(in context: Context) -> AgendaEntry {
        AgendaEntry(date: Date(), events: AppEvent.dummyData[Calendar.current.startOfDay(for: Date())] ?? [])
    }

    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> ()) {
        // Provide a quick snapshot for the widget gallery
        let entry = AgendaEntry(date: Date(), events: AppEvent.dummyData[Calendar.current.startOfDay(for: Date())] ?? [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // This is where we fetch the real data. 
        // We use a detached Task because getTimeline is synchronous but our fetch is async.
        Task {
            var entries: [AgendaEntry] = []
            let currentDate = Date()
            
            // We fetch the next 24 hours of events
            let endDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            
            // Note: In a production App Group, we would read the user's hidden calendars from UserDefaults(suiteName: "group.com...") here.
            do {
                // Ensure we have permission before fetching
                try await eventManager.requestCalendarAccess()
                let fetchedEvents = try await eventManager.fetchEvents(from: currentDate, to: endDate)
                
                // Sort chronologically
                let sortedEvents = fetchedEvents.sorted { $0.startDate < $1.startDate }
                
                // Create the entry
                let entry = AgendaEntry(date: currentDate, events: sortedEvents)
                entries.append(entry)
                
            } catch {
                // If we fail (e.g., no permissions), return an empty state
                entries.append(AgendaEntry(date: currentDate, events: []))
            }
            
            // Update the widget every 30 minutes to save battery, or when the system dictates
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }
}

// MARK: - Widget Entry
struct AgendaEntry: TimelineEntry {
    let date: Date
    let events: [AppEvent]
}

// MARK: - Widget UI (The BC2 Agenda Clone)
struct AgendaWidgetEntryView : View {
    var entry: AgendaProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.densePadding) {
            // Header
            HStack {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(DesignSystem.Typography.header)
                    .foregroundColor(.blue) // iOS Native Header
                Spacer()
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // Dense Event List
            if entry.events.isEmpty {
                Spacer()
                Text("No upcoming events")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(spacing: 2) { // Extremely tight spacing mirroring BC2
                    // Only show up to 4 events to prevent clipping on small widgets
                    ForEach(entry.events.prefix(4)) { event in
                        HStack(spacing: 6) {
                            // Color Tag
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.displayColor)
                                .frame(width: 4)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text(event.title)
                                    .font(DesignSystem.Typography.eventPill)
                                    .lineLimit(1)
                                
                                if !event.isAllDay {
                                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                                        .font(DesignSystem.Typography.timeLabel)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        // iOS 17 specific widget background protocol
        .containerBackground(Color(uiColor: .systemBackground), for: .widget)
    }
}

// MARK: - Widget Configuration
@main
struct AgendaWidget: Widget {
    let kind: String = "AgendaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AgendaProvider()) { entry in
            AgendaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dense Agenda")
        .description("A high-density list of your upcoming events.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge]) 
    }
}