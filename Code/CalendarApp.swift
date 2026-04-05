import SwiftUI

@main
struct CalendarApp: App {
    @StateObject private var viewModel = CalendarViewModel()

    var body: some Scene {
        WindowGroup {
            MonthView(groupedEvents: viewModel.groupedEvents)
                .task {
                    // Ask for permission and load events the second the app opens
                    await viewModel.requestAccessAndFetch()
                }
        }
    }
}