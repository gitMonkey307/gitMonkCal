import SwiftUI
import Foundation

struct AgendaView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String

    private var groupedItemsList: [(Date, [UnifiedAgendaItem])] {
        var items: [UnifiedAgendaItem] = []
        if viewModel.agendaFilter == "all" || viewModel.agendaFilter == "events" {
            let validEvents = viewModel.groupedEvents.values.flatMap { $0 }.filter { $0.startDate >= Date() && (searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)) }
            items.append(contentsOf: validEvents.map { .event($0) })
        }
        if viewModel.agendaFilter == "all" || viewModel.agendaFilter == "tasks" {
            let validTasks = viewModel.reminders.filter { t in
                (!t.isCompleted || !viewModel.hideCompletedTasks) && (searchText.isEmpty || t.title.localizedCaseInsensitiveContains(searchText))
            }
            items.append(contentsOf: validTasks.map { .task($0) })
        }
        let grouped = Dictionary(grouping: items.sorted { $0.sortDate < $1.sortDate }) { Foundation.Calendar.current.startOfDay(for: $0.sortDate) }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterHeader
            List {
                ForEach(groupedItemsList, id: \.0) { date, items in
                    Section(header: Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.headline).foregroundColor(.primary)) {
                        ForEach(items) { item in
                            AgendaRowView(item: item, viewModel: viewModel, searchText: searchText)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .refreshable { await viewModel.refreshData() }
    }

    private var filterHeader: some View {
        HStack {
            // FIXED: Uses centralized FilterChipView
            FilterChipView(title: "All", id: "all", selectedID: $viewModel.agendaFilter)
            FilterChipView(title: "Events", id: "events", selectedID: $viewModel.agendaFilter)
            FilterChipView(title: "Tasks", id: "tasks", selectedID: $viewModel.agendaFilter)
            Spacer()
        }
        .padding(.horizontal).padding(.vertical, 8).background(DesignSystem.Aesthetics.toolbarMaterial)
    }
}
