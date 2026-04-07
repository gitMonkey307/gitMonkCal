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
            FilterChipView(title: "All", id: "all", selectedID: $viewModel.agendaFilter)
            FilterChipView(title: "Events", id: "events", selectedID: $viewModel.agendaFilter)
            FilterChipView(title: "Tasks", id: "tasks", selectedID: $viewModel.agendaFilter)
            Spacer()
        }
        .padding(.horizontal).padding(.vertical, 8).background(DesignSystem.Aesthetics.toolbarMaterial)
    }
}

// FIXED: Restored missing sub-views
struct FilterChipView: View {
    let title: String; let id: String; @Binding var selectedID: String
    var body: some View {
        Button(title) { selectedID = id }
            .font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 6)
            .background(selectedID == id ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(selectedID == id ? .white : .primary).cornerRadius(12)
    }
}

struct AgendaRowView: View {
    let item: UnifiedAgendaItem; @ObservedObject var viewModel: CalendarViewModel; let searchText: String
    var body: some View {
        Group {
            switch item {
            case .event(let event): eventRow(event)
            case .task(let task): taskRow(task)
            }
        }
        .swipeActions(edge: .trailing) { 
            Button(role: .destructive) { delete() } label: { Label("Delete", systemImage: "trash") } 
        }
    }

    @ViewBuilder
    private func eventRow(_ event: AppEvent) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(event.displayColor).frame(width: 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title).font(DesignSystem.Typography.eventPill)
                    .fontWeight(searchText.isEmpty ? .regular : (event.title.localizedCaseInsensitiveContains(searchText) ? .black : .regular))
                Text(event.startDate.formatted(.dateTime.hour().minute())).font(DesignSystem.Typography.timeLabel).foregroundColor(.secondary)
            }
        }
        .onTapGesture { viewModel.editingEvent = event }
    }

    @ViewBuilder
    private func taskRow(_ task: AppReminder) -> some View {
        HStack(spacing: 6) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(task.isCompleted ? .green : .secondary).onTapGesture { Task { await viewModel.toggleReminderCompleted(task) } }
            RoundedRectangle(cornerRadius: 1).fill(task.displayColor).frame(width: CGFloat(task.priority == 1 ? 6 : 2))
            VStack(alignment: .leading, spacing: 0) {
                Text(task.title).font(DesignSystem.Typography.eventPill).strikethrough(task.isCompleted)
                    .fontWeight(searchText.isEmpty ? .regular : (task.title.localizedCaseInsensitiveContains(searchText) ? .black : .regular))
            }
            Spacer()
        }
        .onTapGesture { viewModel.editingTask = task }
    }
    
    private func delete() { switch item { case .event(let e): viewModel.deleteEvent(e); case .task(let t): viewModel.deleteTask(t) } }
}
