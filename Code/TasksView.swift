import SwiftUI

struct TasksView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var showingTaskEdit = false
    @State private var editMode = EditMode.inactive

    var tasks: [AppEvent] { viewModel.allReminders.sorted { $0.startDate < $1.startDate } }

    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(task.priorityColor)
                            .frame(width: 4)
                        VStack(alignment: .leading) {
                            Text(task.title)
                                .font(DesignSystem.Typography.eventPill)
                            if let notes = task.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(DesignSystem.Typography.timeLabel)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button(task.isCompleted ? "Done" : "Complete") {
                            viewModel.toggleTaskCompleted(task)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete { viewModel.deleteReminder(at: $0) }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem { Button("New Task") { showingTaskEdit = true } }
                ToolbarItem { EditButton() }
            }
            .sheet(isPresented: $showingTaskEdit) {
                EventEditView(viewModel: viewModel, isTask: true)
            }
            .refreshable { await viewModel.refreshData() }
        }
    }
}

extension AppEvent {
    var priorityColor: Color {
        Color.orange.opacity(CGFloat(priority ?? 0) / 5)
    }
    var isCompleted: Bool { notes?.contains("completed") == true } // Simple flag
}
