import SwiftUI

@main
struct CalendarApp: App {
    @StateObject private var viewModel = CalendarViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onOpenURL { url in
                    // Logic from gitMonk Interactive: Hand-off from Widget
                    viewModel.handleDeepLink(url: url)
                }
        }
    }
}
