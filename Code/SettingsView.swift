import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        List {
            Section("Calendar Visibility") {
                ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { cal in
                    HStack {
                        Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 12, height: 12)
                        Text(cal.title)
                        Spacer()
                        Image(systemName: viewModel.visibleCalendarIDs.contains(cal.calendarIdentifier) ? "checkmark.circle.fill" : "circle")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await viewModel.toggleCalendarVisibility(calendarID: cal.calendarIdentifier) } }
                }
            }
            
            Section("Quick Templates") {
                if viewModel.templates.isEmpty {
                    Text("No templates saved").foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.templates) { temp in
                        Text(temp.title)
                    }
                    .onDelete(perform: viewModel.deleteTemplate)
                }
            }

            Section("Pro Customizations") {
                Toggle("High Density Mode", isOn: Binding(
                    get: { viewModel.isHighDensity },
                    set: { val in viewModel.updateSettings(hideTasks: viewModel.hideCompletedTasks, duration: viewModel.defaultDuration, themeHex: viewModel.themeColorHex, firstDay: viewModel.firstDayOfWeek, density: val) }
                ))
                Picker("First Day of Week", selection: Binding(
                    get: { viewModel.firstDayOfWeek },
                    set: { val in viewModel.updateSettings(hideTasks: viewModel.hideCompletedTasks, duration: viewModel.defaultDuration, themeHex: viewModel.themeColorHex, firstDay: val, density: viewModel.isHighDensity) }
                )) { Text("Sunday").tag(1); Text("Monday").tag(2) }
                Toggle("Hide Completed Tasks", isOn: Binding(
                    get: { viewModel.hideCompletedTasks },
                    set: { val in viewModel.updateSettings(hideTasks: val, duration: viewModel.defaultDuration, themeHex: viewModel.themeColorHex, firstDay: viewModel.firstDayOfWeek, density: viewModel.isHighDensity); Task { await viewModel.refreshData() } }
                ))
            }
            
            Section("App Theme") {
                Picker("Accent Color", selection: Binding(
                    get: { viewModel.themeColorHex },
                    set: { val in viewModel.updateSettings(hideTasks: viewModel.hideCompletedTasks, duration: viewModel.defaultDuration, themeHex: val, firstDay: viewModel.firstDayOfWeek, density: viewModel.isHighDensity) }
                )) {
                    Text("Blue").tag("#007AFF"); Text("Red").tag("#FF3B30"); Text("Green").tag("#34C759"); Text("Orange").tag("#FF9500"); Text("Purple").tag("#AF52DE")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.refreshData() }
    }
}
