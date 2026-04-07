import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        List {
            Section(header: Text("gitMonk Interactive Hub")) {
                Button("Force Database Refresh") {
                    Task { await viewModel.refreshData() }
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Section(header: Text("Calendar Visibility")) {
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
            
            Section(header: Text("Reminder Lists")) {
                ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { list in
                    HStack {
                        Circle().fill(Color(cgColor: list.cgColor)).frame(width: 12, height: 12)
                        Text(list.title)
                        Spacer()
                        Image(systemName: viewModel.visibleReminderListIDs.contains(list.calendarIdentifier) ? "checkmark.circle.fill" : "circle")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await viewModel.toggleReminderListVisibility(listID: list.calendarIdentifier) } }
                }
            }
            
            Section(header: Text("Pro Customizations")) {
                Group {
                    Toggle("High Density Mode", isOn: Binding(
                        get: { viewModel.isHighDensity },
                        set: { val in viewModel.updateSettings(hideTasks: viewModel.hideCompletedTasks, duration: viewModel.defaultDuration, themeHex: viewModel.themeColorHex, firstDay: viewModel.firstDayOfWeek, density: val) }
                    ))
                    Toggle("Hide Completed Tasks", isOn: Binding(
                        get: { viewModel.hideCompletedTasks },
                        set: { val in viewModel.updateSettings(hideTasks: val, duration: viewModel.defaultDuration, themeHex: viewModel.themeColorHex, firstDay: viewModel.firstDayOfWeek, density: viewModel.isHighDensity); Task { await viewModel.refreshData() } }
                    ))
                }
            }
            
            Section(header: Text("Quick Templates")) {
                if viewModel.templates.isEmpty {
                    Text("No templates saved").foregroundColor(.secondary).font(.caption)
                } else {
                    ForEach(viewModel.templates) { temp in
                        Text(temp.title)
                    }
                    .onDelete(perform: viewModel.deleteTemplate)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
