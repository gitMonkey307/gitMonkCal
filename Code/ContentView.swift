import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // FIXED: Using selection binding to force detail view navigation
            List(selection: $viewModel.selectedView) {
                Section("Views") {
                    SidebarItem(title: "Month", icon: "calendar", id: "month")
                    SidebarItem(title: "Multi-Day", icon: "calendar.day.timeline.left", id: "week")
                    SidebarItem(title: "Day", icon: "calendar.day.timeline.leading", id: "day")
                    SidebarItem(title: "Agenda", icon: "list.bullet", id: "agenda")
                    SidebarItem(title: "Tasks", icon: "checkmark.circle", id: "tasks")
                    SidebarItem(title: "Year", icon: "calendar.circle", id: "year")
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
                    SidebarItem(title: "Preferences", icon: "gearshape", id: "settings")
                }
            }
            .navigationTitle("gitMonkCal")
        } detail: {
            detailStack
        }
        .tint(Color(viewModel.themeColorHex) ?? .blue)
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
    
    private var detailStack: some View {
        ZStack(alignment: .bottomTrailing) {
            mainContent
                .searchable(text: $viewModel.searchText)
                .onSubmit(of: .search) { viewModel.addToSearchHistory(viewModel.searchText) }
                .navigationTitle(viewModel.selectedView?.capitalized ?? "Calendar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { viewModel.jumpToToday() } label: { Text("Today").fontWeight(.semibold) }
                        Button { viewModel.showDatePicker = true } label: { Image(systemName: "calendar.badge.clock") }
                    }
                }
            
            if viewModel.selectedView != "settings" {
                floatingActionButton
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        // FIXED: Handles optional string for selection
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
                .background(Circle().fill(Color(viewModel.themeColorHex) ?? .blue).shadow(radius: 4))
        }
        .padding(24)
    }
}

// FIXED: Using Tag for standard selection behavior
struct SidebarItem: View {
    let title: String; let icon: String; let id: String
    var body: some View {
        Label(title, systemImage: icon)
            .tag(id) 
    }
}
