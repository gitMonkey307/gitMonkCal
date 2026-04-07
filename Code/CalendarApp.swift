import SwiftUI

@main
struct gitMonkCalApp: App {
    @StateObject private var viewModel = CalendarViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onOpenURL { url in
                    Task { @MainActor in
                        viewModel.handleDeepLink(url: url)
                    }
                }
        }
    }
}
