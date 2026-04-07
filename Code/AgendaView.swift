import SwiftUI

enum UnifiedAgendaItem: Identifiable {
    case event(AppEvent)
    case task(AppReminder)
    var id: String { switch self { case .event(let e): return "e_" + e.id; case .task(let t): return "t_" + t.id } }
    var sortDate: Date { switch self { case .event(let e): return e.startDate; case .task(let t): return t.dueDate ?? Date.distantFuture } }
}

struct AgendaView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String

    // Feature: Data sorted and grouped by actual Day Headers
    private var groupedItems: [(Date, [UnifiedAgendaItem])] {
        var items: [UnifiedAgendaItem] = []
        let validEvents = viewModel.groupedEvents.values.flatMap { $0 }.filter { $0.startDate >= Date() && (searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)) }
        items.append(contentsOf: validEvents.map { .event($0) })
        
        let validTasks = viewModel.reminders.filter { t in
            (!t.isCompleted || !viewModel.hideCompletedTasks) && (searchText.isEmpty || t.title.localizedCaseInsensitiveContains(searchText))
        }
        items.append(contentsOf: validTasks.map { .task($0) })
        let sorted = items.sorted { $0.sortDate < $1.sortDate }
        
        let grouped = Dictionary(grouping: sorted) { Calendar.current.startOfDay(for: $0.sortDate) }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        List {
            ForEach(groupedItems, id: \.0) { date, items in
                Section(header: Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.headline).foregroundColor(.primary)) {
                    ForEach(items) { item in
                        AgendaRowView(item: item, viewModel: viewModel)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refreshData() }
    }
}

// STRICT TYPING & AST ISOLATION: Sub-struct for Swipe Actions to prevent compiler crash
struct AgendaRowView: View {
    let item: UnifiedAgendaItem
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        Group {
            switch item {
            case .event(let event):
                VStack(alignment: .leading, spacing: DesignSystem.Layout.densePadding) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(event.displayColor).frame(width: 4)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                if event.isBirthday { Text("🎁").font(.system(size: 10)) }
                                Text(event.title).font(DesignSystem.Typography.eventPill).lineLimit(1)
                            }
                            Text(event.startDate.formatted(.dateTime.hour().minute()))
                                .font(DesignSystem.Typography.timeLabel).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.editingEvent = event }
                .contextMenu {
                    Button { viewModel.eventToDuplicate = event } label: { Label("Duplicate", systemImage: "doc.on.doc") }
                }
                
            case .task(let task):
                HStack(spacing: 6) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : .secondary)
                        .font(.title3)
                        .onTapGesture { Task { await viewModel.toggleReminderCompleted(task) } }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 2) {
                            if task.priority > 0 && task.priority < 5 { Text("!!").font(.caption).foregroundColor(.red).bold() } // Feature: Priority Marker
                            Text(task.title).font(DesignSystem.Typography.eventPill).strikethrough(task.isCompleted)
                        }
                        if let dueDate = task.dueDate {
                            Text(dueDate.formatted(.dateTime.hour().minute()))
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete() } label: { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if case .task(let t) = item {
                Button { Task { await viewModel.toggleReminderCompleted(t) } } label: { Label("Complete", systemImage: "checkmark.circle.fill") }.tint(.green)
            }
        }
    }
    
    private func delete() {
        switch item {
        case .event(let e): viewModel.deleteEvent(e)
        case .task(let t): viewModel.deleteTask(t)
        }
    }
}
