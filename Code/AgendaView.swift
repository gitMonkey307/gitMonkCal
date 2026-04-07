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

    private var groupedItems: [(Date, [UnifiedAgendaItem])] {
        var items: [UnifiedAgendaItem] = []
        
        // Respect Agenda Filter Logic
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
        
        let sorted = items.sorted { $0.sortDate < $1.sortDate }
        let grouped = Dictionary(grouping: sorted) { Calendar.current.startOfDay(for: $0.sortDate) }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterHeader
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
        }
        .refreshable { await viewModel.refreshData() }
    }
    
    // Feature: BC2 Filter Chips
    private var filterHeader: some View {
        HStack {
            FilterChip(title: "All", id: "all", selectedID: $viewModel.agendaFilter)
            FilterChip(title: "Events", id: "events", selectedID: $viewModel.agendaFilter)
            FilterChip(title: "Tasks", id: "tasks", selectedID: $viewModel.agendaFilter)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(DesignSystem.Aesthetics.toolbarMaterial)
    }
}

struct FilterChip: View {
    let title: String; let id: String
    @Binding var selectedID: String
    var body: some View {
        Button(title) { selectedID = id }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selectedID == id ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(selectedID == id ? .white : .primary)
            .cornerRadius(12)
    }
}

struct AgendaRowView: View {
    let item: UnifiedAgendaItem
    @ObservedObject var viewModel: CalendarViewModel
    var body: some View {
        Group {
            switch item {
            case .event(let event): eventRow(event)
            case .task(let task): taskRow(task)
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

    @ViewBuilder
    private func eventRow(_ event: AppEvent) -> some View {
        HStack(spacing: 6) {
            if event.isAllDay {
                Text(event.title).font(DesignSystem.Typography.eventPill).foregroundColor(.white).padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading).background(event.displayColor.cornerRadius(4))
            } else {
                RoundedRectangle(cornerRadius: 2).fill(event.displayColor).frame(width: 4)
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if event.isBirthday { Text("🎁").font(.system(size: 10)) }
                        Text(event.title).font(DesignSystem.Typography.eventPill).lineLimit(1)
                    }
                    Text(event.startDate.formatted(.dateTime.hour().minute())).font(DesignSystem.Typography.timeLabel).foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .onTapGesture { viewModel.editingEvent = event }
    }

    @ViewBuilder
    private func taskRow(_ task: AppReminder) -> some View {
        HStack(spacing: 6) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(task.isCompleted ? .green : .secondary).onTapGesture { Task { await viewModel.toggleReminderCompleted(task) } }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if task.priority > 0 && task.priority < 5 { Text("!!").font(.caption).foregroundColor(.red).bold() }
                    Text(task.title).font(DesignSystem.Typography.eventPill).strikethrough(task.isCompleted)
                }
                if let dueDate = task.dueDate { Text(dueDate.formatted(.dateTime.hour().minute())).font(DesignSystem.Typography.timeLabel).foregroundColor(.secondary) }
            }
            Spacer()
            RoundedRectangle(cornerRadius: 2).fill(task.displayColor).frame(width: 4)
        }
        .onTapGesture { viewModel.editingTask = task }
    }
    
    private func delete() { switch item { case .event(let e): viewModel.deleteEvent(e); case .task(let t): viewModel.deleteTask(t) } }
}
