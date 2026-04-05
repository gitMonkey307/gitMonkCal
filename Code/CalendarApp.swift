import SwiftUI

@main
struct CalendarApp: App {
    @StateObject private var viewModel = CalendarViewModel()
    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
        }
    }
}
