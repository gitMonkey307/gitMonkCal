import SwiftUI

@main
struct CalendarApp: App {
    // Initialize the central engine exactly once when the app launches
    @StateObject private var viewModel = CalendarViewModel()
    
    // Watch the iOS system state to know when the app is opened or backgrounded
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel) // Optional: Makes viewModel available to deep views
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // Pro Feature: Auto-refresh the calendar the second the user opens the app
                Task {
                    await viewModel.refreshData()
                }
            case .inactive, .background:
                // App is swiped away or user goes to home screen
                // You can add logic here in the future to save specific UI states if needed
                break
            @unknown default:
                break
            }
        }
    }
}
