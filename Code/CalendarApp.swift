import SwiftUI

@main
struct CalendarApp: App {
    @StateObject private var viewModel = CalendarViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        // iOS 17 Native two-parameter implementation
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active { Task { await viewModel.refreshData() } }
        }
    }
}
