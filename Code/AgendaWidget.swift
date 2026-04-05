import WidgetKit
import SwiftUI
import EventKit

struct AgendaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AgendaEntry {
        AgendaEntry(date: Date(), events: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> ()) {
        let entry = AgendaEntry(date: Date(), events: [])
        completion(entry)
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
                entries.append(AgendaEntry(date: currentDate, events: Array(sortedEvents.prefix(5))))
            } catch {
                entries.append(AgendaEntry(date: currentDate, events: []))
            }
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct AgendaEntry: TimelineEntry {
    let date: Date
    let events: [AppEvent]
}

struct AgendaWidgetEntryView: View {
    var entry: AgendaProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.densePadding) {
            HStack {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(DesignSystem.Typography.header)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundColor(.secondary
