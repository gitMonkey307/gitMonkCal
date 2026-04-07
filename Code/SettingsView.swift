import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        List {
            Section("Reminder Lists") {
                ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { list in
                    HStack {
                        Circle().fill(Color(cgColor: list.cgColor) ?? .green).frame(width: 12, height: 12)
                        Text(list.title).font(DesignSystem.Typography.body)
                        Spacer()
                        Image(systemName: viewModel.visibleReminderListIDs.contains(list.calendarIdentifier) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.visibleReminderListIDs.contains(list.calendarIdentifier) ? .green : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await viewModel.toggleReminderListVisibility(listID: list.calendarIdentifier) } }
                }
            }

            Section("Pro Customizations") {
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
                
                Picker("First Day of Week", selection: Binding(
                    get: { viewModel.firstDayOfWeek },
                    set: { val in viewModel.updateSettings(hideTasks: viewModel.hideCompletedTasks, duration: viewModel.defaultDuration, themeHex: viewModel.themeColorHex, firstDay: val) }
                )) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                }
                
                Toggle("Hide Completed Tasks", isOn: Binding(
                    get: { viewModel.hideCompletedTasks },
                    set: { val in viewModel.updateSettings(hideTasks: val, duration: viewModel.defaultDuration, themeHex: viewModel.themeColorHex, firstDay: viewModel.firstDayOfWeek); Task { await viewModel.refreshData() } }
                ))
                Picker("Default Event Duration", selection: Binding(
                    get: { viewModel.defaultDuration },
                    set: { val in viewModel.updateSettings(hideTasks: viewModel.hideCompletedTasks, duration: val, themeHex: viewModel.themeColorHex, firstDay: viewModel.firstDayOfWeek) }
                )) {
                    Text("15 Mins").tag(15); Text("30 Mins").tag(30); Text("1 Hour").tag(60); Text("2 Hours").tag(120)
                }
            }
            
            Section("App Theme") {
                Picker("Accent Color", selection: Binding(
                    get: { viewModel.themeColorHex },
                    set: { val in viewModel.updateSettings(hideTasks: viewModel.hideCompletedTasks, duration: viewModel.defaultDuration, themeHex: val, firstDay: viewModel.firstDayOfWeek) }
                )) {
                    Text("Blue").tag("#007AFF")
                    Text("Red").tag("#FF3B30")
                    Text("Green").tag("#34C759")
                    Text("Orange").tag("#FF9500")
                    Text("Purple").tag("#AF52DE")
                }
            }

            if viewModel.isLoading { Section { ProgressView() } }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.refreshData() }
    }
}
