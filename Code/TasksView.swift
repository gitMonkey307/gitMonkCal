import SwiftUI

struct TasksView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String

    private var validTasks: [AppReminder] {
        // FIXED: Accessing filteredReminders from VM correctly
        viewModel.filteredReminders.filter { task in
            !task.isCompleted || !viewModel.hideCompletedTasks
        }
    }

    var body: some View {
        List {
            ForEach(validTasks, id: \.id) { reminder in
                HStack(spacing: DesignSystem.Layout.densePadding) {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(reminder.isCompleted ? .green : .secondary)
                        .font(.title3)
                        .onTapGesture { Task { await viewModel.toggleReminderCompleted(reminder) } }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 2) {
                            if reminder.priority > 0 && reminder.priority < 5 { Text("!!").font(.caption).foregroundColor(.red).bold() }
                            Text(reminder.title).font(DesignSystem.Typography.eventPill).strikethrough(reminder.isCompleted)
                        }
                        if let dueDate = reminder.dueDate {
                            Text(dueDate.formatted(.dateTime.hour().minute())).font(DesignSystem.Typography.timeLabel).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 2).fill(reminder.displayColor).frame(width: 4)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.editingTask = reminder }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refreshData() }
    }
}
