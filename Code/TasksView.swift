import SwiftUI

struct TasksView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String

    private var filteredReminders: [AppReminder] {
        viewModel.filteredReminders
    }

    var body: some View {
        List {
            ForEach(filteredReminders) { reminder in
                HStack(spacing: DesignSystem.Layout.densePadding) {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(reminder.isCompleted ? .green : .secondary)
                        .font(.title3)
                        .onTapGesture {
                            Task {
                                await viewModel.toggleReminderCompleted(reminder)
                            }
                        }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(reminder.title)
                            .font(DesignSystem.Typography.eventPill)
                            .strikethrough(reminder.isCompleted)
                        if let dueDate = reminder.dueDate {
                            Text(dueDate.formatted(.dateTime.hour().minute()))
                                .font(DesignSystem.Typography.timeLabel)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(reminder.displayColor)
                        .frame(width: 4)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refreshReminders()
        }
    }
}
