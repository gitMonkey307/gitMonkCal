import SwiftUI

// STRICT TYPING: Encapsulates both types for a unified chronological list
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
        
        let validTasks = viewModel.reminders.filter {
            !$0.isCompleted && (searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText))
        }
        items.append(contentsOf: validTasks.map { .task($0) })
        
        // Sort chronologically regardless of type
        let sortedItems = items.sorted { $0.sortDate < $1.sortDate }
        return Array(sortedItems.prefix(100))
    }

    var body: some View {
        List {
            ForEach(upcomingItems, id: \.id) { item in
                switch item {
                case .event(let event):
                    eventRow(for: event)
                case .task(let task):
                    taskRow(for: task)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refreshData() }
    }
    
    // MARK: - Row Components
    @ViewBuilder
    private func eventRow(for event: AppEvent) -> some View {
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
    }
    
    @ViewBuilder
    private func taskRow(for task: AppReminder) -> some View {
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
