import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        List {
            Section("Reminder Lists") {
                ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { list in
                    HStack {
                        Circle().fill(Color(hex: list.cgColor.toHexString() ?? "#34C759") ?? .green).frame(width: 12, height: 12)
                        Text(list.title).font(DesignSystem.Typography.body)
                        Spacer()
                        Image(systemName: viewModel.visibleReminderListIDs.contains(list.calendarIdentifier) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.visibleReminderListIDs.contains(list.calendarIdentifier) ? .green : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await viewModel.toggleReminderListVisibility(listID: list.calendarIdentifier) } }
                }
            }

            Section("Customizations") {
                HStack {
                    Text("Core Hours")
                    Spacer()
                    HStack {
                        Text("\(viewModel.coreHourStart):00")
                        Slider(value: Binding(get: { Double(viewModel.coreHourStart) }, set: { viewModel.updateCoreHours(start: Int($0), end: viewModel.coreHourEnd) }), in: 0...23, step: 1)
                        Text("\(viewModel.coreHourEnd):00")
                    }
                }
                HStack {
                    Text("Event Opacity")
                    Spacer()
                    Slider(value: $viewModel.eventOpacity, in: 0.1...1.0, step: 0.1)
                }
            }

            if viewModel.isLoading { Section { ProgressView() } }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.refreshData() }
    }
}
