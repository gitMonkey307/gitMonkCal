import SwiftUI

struct TasksView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String

    // Feature: Hide Completed Tasks
    private var validTasks: [AppReminder] {
        viewModel.filteredReminders.filter { task in
            !task.isCompleted || !viewModel.hideCompletedTasks
        }
    }

    var body: some View {
        List {
            ForEach(validTasks) { reminder in
                HStack(spacing: DesignSystem.Layout.densePadding) {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(reminder.isCompleted ? .green : .secondary)
                        .font(.title3)
                        .onTapGesture { Task { await viewModel.toggleReminderCompleted(reminder) } }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(reminder.title).font(DesignSystem.Typography.eventPill).strikethrough(reminder.isCompleted)
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
