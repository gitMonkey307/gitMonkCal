import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedTab = 0
    @State private var showingEventEdit = false
    @State private var searchText = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            MonthView(viewModel: viewModel, searchText: searchText)
                .tabItem {
                    Label("Month", systemImage: "calendar")
                }.tag(0)

            MultiDayView(viewModel: viewModel, numberOfDays: 7, searchText: searchText) // Week
                .tabItem {
                    Label("Week", systemImage: "calendar.view.week.timeline")
                }.tag(1)

            DayView(viewModel: viewModel, searchText: searchText)
                .tabItem {
                    Label("Day", systemImage: "calendar.day.timeline.leading")
                }.tag(2)

            AgendaView(viewModel: viewModel, searchText: searchText)
                .tabItem {
                    Label("Agenda", systemImage: "list.bullet")
                }.tag(3)

            TasksView(viewModel: viewModel, searchText: searchText)
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle")
                }.tag(4)

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }.tag(5)
        }
        .searchable(text: $searchText)
        .navigationTitle("gitMonkCal")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEventEdit = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEventEdit) {
            EventEditView(viewModel: viewModel)
        }
        .task {
            await viewModel.requestAccessAndFetch()
        }
        .onChange(of: searchText) { _ in
            // Filter handled per view
        }
    }
}
