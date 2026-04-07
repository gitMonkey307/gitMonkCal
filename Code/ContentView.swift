import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarList
                .navigationTitle("gitMonkCal")
        } detail: {
            detailStack
        }
        // GLOBAL ROUTING
        .sheet(isPresented: $viewModel.isAddingNew) { EventEditView(viewModel: viewModel) }
        .sheet(item: $viewModel.editingEvent) { ev in EventEditView(viewModel: viewModel, eventToEdit: ev) }
        .sheet(item: $viewModel.editingTask) { tk in EventEditView(viewModel: viewModel, taskToEdit: tk) }
        .task { await viewModel.requestAccessAndFetch() }
    }
    
    private var sidebarList: some View {
        List {
            Section("Views") {
                SidebarRow(title: "Month", icon: "calendar", id: "month", selected: $viewModel.selectedView)
                SidebarRow(title: "Multi-Day", icon: "calendar.day.timeline.left", id: "week", selected: $viewModel.selectedView)
                SidebarRow(title: "Day", icon: "calendar.day.timeline.leading", id: "day", selected: $viewModel.selectedView)
                SidebarRow(title: "Agenda", icon: "list.bullet", id: "agenda", selected: $viewModel.selectedView)
                SidebarRow(title: "Tasks", icon: "checkmark.circle", id: "tasks", selected: $viewModel.selectedView)
                SidebarRow(title: "Year", icon: "calendar.circle", id: "year", selected: $viewModel.selectedView)
            }
            Section("Calendars") {
                ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { cal in
                    Toggle(cal.title, isOn: Binding(
                        get: { viewModel.visibleCalendarIDs.contains(cal.calendarIdentifier) },
                        set: { _ in Task { await viewModel.toggleCalendarVisibility(calendarID: cal.calendarIdentifier) } }
                    ))
                    .tint(Color(cgColor: cal.cgColor))
                }
            }
            Section("Settings") {
                SidebarRow(title: "Preferences", icon: "gearshape", id: "settings", selected: $viewModel.selectedView)
            }
        }
    }
    
    private var detailStack: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                switch viewModel.selectedView {
                case "month": MonthView(viewModel: viewModel, searchText: viewModel.searchText)
                case "week": MultiDayView(viewModel: viewModel)
                case "day": DayView(viewModel: viewModel, searchText: viewModel.searchText)
                case "agenda": AgendaView(viewModel: viewModel, searchText: viewModel.searchText)
                case "tasks": TasksView(viewModel: viewModel, searchText: viewModel.searchText)
                case "year": YearView(viewModel: viewModel)
                case "settings": SettingsView(viewModel: viewModel)
                default: MonthView(viewModel: viewModel, searchText: viewModel.searchText)
                }
            }
            .searchable(text: $viewModel.searchText)
            .navigationTitle(viewModel.selectedView.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            
            if viewModel.selectedView != "settings" {
                Button { viewModel.isAddingNew = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.blue).shadow(radius: 4))
                }
                .padding(24)
            }
        }
    }
}

struct SidebarRow: View {
    let title: String; let icon: String; let id: String
    @Binding var selected: String
    var body: some View {
        Button(action: { selected = id }) {
            Label(title, systemImage: icon).foregroundColor(selected == id ? .blue : .primary)
        }
    }
}
