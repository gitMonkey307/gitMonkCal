import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var showingEventEdit = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
                        )).tint(Color(uiColor: cal.cgColor))
                    }
                }
                Section("Settings") {
                    SidebarRow(title: "Preferences", icon: "gearshape", id: "settings", selected: $viewModel.selectedView)
                }
            }
            .navigationTitle("gitMonkCal")
        } detail: {
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
                    Button { showingEventEdit = true } label: {
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
        .sheet(isPresented: $showingEventEdit) { EventEditView(viewModel: viewModel) }
        .task { await viewModel.requestAccessAndFetch() }
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
