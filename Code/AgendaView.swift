import SwiftUI

enum UnifiedAgendaItem: Identifiable {
    case event(AppEvent)
    case task(AppReminder)
    
    var id: String {
        switch self {
        case .event(let e): return "e_" + e.id
        case .task(let t): return "t_" + t.id
        }
    }
    
    var sortDate: Date {
        switch self {
        case .event(let e): return e.startDate
        case .task(let t): return t.dueDate ?? Date.distantFuture
        }
    }
}

struct AgendaView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String

    private var upcomingItems: [UnifiedAgendaItem] {
        var items: [UnifiedAgendaItem] = []
        
        let validEvents = viewModel.groupedEvents.values.flatMap { $0 }.filter {
            $0.startDate >= Date() && (searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText))
        }
        items.append(contentsOf: validEvents.map { .event($0) })
        
        let validTasks = viewModel.reminders.filter { task in
            let matchSearch = searchText.isEmpty || task.title.localizedCaseInsensitiveContains(searchText)
            // Feature: Hide Completed Tasks Filter
            let matchCompletion = !task.isCompleted || !viewModel.hideCompletedTasks
            return matchSearch && matchCompletion
        }
        items.append(contentsOf: validTasks.map { .task($0) })
        
        let sortedItems = items.sorted { $0.sortDate < $1.sortDate }
        return Array(sortedItems.prefix(100))
    }

    var body: some View {
        List {
            ForEach(upcomingItems, id: \.id) { item in
                row(for: item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { delete(item: item) } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if case .task(let t) = item {
                            Button { Task { await viewModel.toggleReminderCompleted(t) } } label: { Label("Complete", systemImage: "checkmark.circle.fill") }.tint(.green)
                        }
                    }
                    // Feature: Event Duplication
                    .contextMenu {
                        if case .event(let e) = item {
                            Button { viewModel.eventToDuplicate = e } label: { Label("Duplicate", systemImage: "doc.on.doc") }
                        }
                    }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refreshData() }
    }
    
    @ViewBuilder
    private func row(for item: UnifiedAgendaItem) -> some View {
        switch item {
        case .event(let event):
            VStack(alignment: .leading, spacing: DesignSystem.Layout.densePadding) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(event.displayColor).frame(width: 4)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.title).font(DesignSystem.Typography.eventPill).lineLimit(1)
                        Text(event.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(DesignSystem.Typography.timeLabel).foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.editingEvent = event }
            
        case .task(let task):
            HStack(spacing: 6) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .secondary)
                    .font(.title3)
                    .onTapGesture { Task { await viewModel.toggleReminderCompleted(task) } }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(task.title).font(DesignSystem.Typography.eventPill).strikethrough(task.isCompleted)
                    if let dueDate = task.dueDate {
                        Text(dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(DesignSystem.Typography.timeLabel).foregroundColor(.secondary)
                    }
                }
                Spacer()
                RoundedRectangle(cornerRadius: 2).fill(task.displayColor).frame(width: 4)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.editingTask = task }
        }
    }
    
    private func delete(item: UnifiedAgendaItem) {
        switch item {
        case .event(let e): viewModel.deleteEvent(e)
        case .task(let t): viewModel.deleteTask(t)
        }
    }
}
