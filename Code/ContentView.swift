import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var searchText = ""
    @State private var showingEventEdit = false
    @State private var selectedDate = Date()
    @AppStorage("theme") private var theme: Int = 0 // 0=system, 1-22 custom

    var filteredEvents: [AppEvent] {
        let allEvents = viewModel.groupedEvents.values.flatMap { $0 }
        if searchText.isEmpty { return allEvents }
        return allEvents.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.notes?.localizedCaseInsensitiveContains(searchText) == true }
    }

    var body: some View {
        NavigationStack {
            TabView {
                MonthView(viewModel: viewModel, selectedDate: $selectedDate)
                    .tabItem { Label("Month", systemImage: "calendar") }

                MultiDayView(viewModel: viewModel)
                    .tabItem { Label("Week", systemImage: "calendar.view.week.timeline") }

                DayView(viewModel: viewModel, date: selectedDate)
                    .tabItem { Label("Day", systemImage: "calendar.day.timeline.leading") }

                AgendaView(viewModel: viewModel, searchText: searchText)
                    .tabItem { Label("Agenda", systemImage: "list.bullet") }

                TasksView(viewModel: viewModel)
                    .tabItem { Label("Tasks", systemImage: "checkmark.circle") }

                SettingsView(viewModel: viewModel)
                    .tabItem { Label("More", systemImage: "ellipsis") }
            }
            .searchable(text: $searchText)
            .navigationTitle("gitMonkCal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingEventEdit = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEventEdit) {
                EventEditView(viewModel: viewModel, selectedDate: selectedDate)
            }
            .preferredColorScheme(theme == 0 ? nil : .light) // Themes: extend for dark/custom
            .task { await viewModel.requestAccessAndFetch() }
        }
    }
}
