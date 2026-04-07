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
        // Universal Theme Tint Applied Here
        .tint(Color(hex: viewModel.themeColorHex) ?? .blue)
        .sheet(isPresented: $viewModel.isAddingNew, onDismiss: { viewModel.targetDateForNewItem = nil }) {
            EventEditView(viewModel: viewModel, initialDate: viewModel.targetDateForNewItem)
        }
        .sheet(item: $viewModel.editingEvent) { ev in EventEditView(viewModel: viewModel, eventToEdit: ev) }
        .sheet(item: $viewModel.editingTask) { tk in EventEditView(viewModel: viewModel, taskToEdit: tk) }
        .sheet(item: $viewModel.eventToDuplicate) { dup in EventEditView(viewModel: viewModel, eventToDuplicate: dup) }
        .sheet(isPresented: $viewModel.showDatePicker) {
            NavigationView {
                DatePicker("Jump To Date", selection: $viewModel.anchorDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("Go To Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { viewModel.showDatePicker = false } }
            }
            .presentationDetents([.medium])
        }
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
            mainContent
                .searchable(text: $viewModel.searchText)
                .navigationTitle(viewModel.selectedView.capitalized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Feature: Jump To Date Button
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { viewModel.showDatePicker = true } label: {
                            Image(systemName: "calendar.badge.clock")
                        }
                    }
                }
            
            if viewModel.selectedView != "settings" {
                floatingActionButton
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
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
    
    private var floatingActionButton: some View {
        Button {
            viewModel.targetDateForNewItem = Date()
            viewModel.isAddingNew = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color(hex: viewModel.themeColorHex) ?? .blue).shadow(radius: 4))
        }
        .padding(24)
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
