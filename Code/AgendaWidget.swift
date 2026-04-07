import WidgetKit
import SwiftUI
import EventKit
import Foundation

struct AgendaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AgendaEntry { AgendaEntry(date: Date(), events: []) }
    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> ()) { completion(AgendaEntry(date: Date(), events: [])) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let currentDate = Date()
            let endDate = Foundation.Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            let eventManager = EventKitManager()
            var entryEvents: [AppEvent] = []
            do {
                try await eventManager.requestCalendarAccess()
                entryEvents = try await eventManager.fetchEvents(from: currentDate, to: endDate)
            } catch { print("Widget auth fail") }
            let nextUpdate = Foundation.Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
            completion(Timeline(entries: [AgendaEntry(date: currentDate, events: entryEvents)], policy: .after(nextUpdate)))
        }
    }
}

struct AgendaEntry: TimelineEntry { let date: Date; let events: [AppEvent] }

struct AgendaWidgetEntryView : View {
    var entry: AgendaProvider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.date.formatted(.dateTime.weekday(.wide).month().day())).font(.system(size: 14, weight: .bold)).foregroundColor(.blue) 
            Divider()
            if entry.events.isEmpty {
                Text("No events").font(.system(size: 12)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                ForEach(entry.events.prefix(4)) { event in
                    // NEW: Deep-Link Routing for gitMonk Interactive
                    Link(destination: URL(string: "gitmonkcal://event/\(event.id)")!) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(event.displayColor).frame(width: 4)
                            Text(event.title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                        }
                    }
                }
            }
            Spacer()
        }
        .containerBackground(Color(uiColor: .systemBackground), for: .widget)
    }
}

@main
struct AgendaWidget: Widget {
    let kind: String = "AgendaWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AgendaProvider()) { entry in AgendaWidgetEntryView(entry: entry) }
        .configurationDisplayName("gitMonk Agenda")
        .description("Unified schedule by gitMonk Interactive.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge]) 
    }
}
