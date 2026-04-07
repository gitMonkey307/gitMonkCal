import WidgetKit
import SwiftUI
import EventKit

struct AgendaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AgendaEntry {
        AgendaEntry(date: Date(), events: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> ()) {
        completion(AgendaEntry(date: Date(), events: []))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            var entries: [AgendaEntry] = []
            let currentDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            
            let eventManager = EventKitManager()
            do {
                try await eventManager.requestCalendarAccess()
                let fetchedEvents = try await eventManager.fetchEvents(from: currentDate, to: endDate)
                let sortedEvents = fetchedEvents.sorted { $0.startDate < $1.startDate }
                entries.append(AgendaEntry(date: currentDate, events: sortedEvents))
            } catch {
                entries.append(AgendaEntry(date: currentDate, events: []))
            }
            
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
            completion(Timeline(entries: entries, policy: .after(nextUpdate)))
        }
    }
}

struct AgendaEntry: TimelineEntry {
    let date: Date
    let events: [AppEvent]
}

struct AgendaWidgetEntryView : View {
    var entry: AgendaProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month().day())).font(.system(size: 14, weight: .bold)).foregroundColor(.blue) 
                Spacer()
                Image(systemName: "calendar").foregroundColor(.secondary)
            }
            .padding(.bottom, 2)
            Divider()
            
            if entry.events.isEmpty {
                Spacer()
                Text("No upcoming events").font(.system(size: 12)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(spacing: 2) { 
                    ForEach(entry.events.prefix(4)) { event in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(event.displayColor).frame(width: 4)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(event.title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                                if !event.isAllDay {
                                    Text(event.startDate.formatted(date: .omitted, time: .shortened)).font(.system(size: 8)).foregroundColor(.secondary)
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
        .containerBackground(Color(uiColor: .systemBackground), for: .widget)
    }
}

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
