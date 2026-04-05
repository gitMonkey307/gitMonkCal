import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        List {
            Section("Navigation") {
                ViewLink(title: "Month", icon: "calendar", id: "month", vm: viewModel)
                ViewLink(title: "Multi-Day", icon: "calendar.day.timeline.left", id: "week", vm: viewModel)
                ViewLink(title: "Agenda", icon: "list.bullet.rectangle", id: "agenda", vm: viewModel)
            }
            
            Section("Filters") {
                Toggle("Show Completed Tasks", isOn: $viewModel.showCompletedTasks)
                    .onChange(of: viewModel.showCompletedTasks) { _ in viewModel.applyFilters() }
            }
            
            Section("Calendars") {
                // Here we would map out each specific calendar from EventKit
                Label("Personal", systemImage: "circle.fill").foregroundColor(.blue)
                Label("Work", systemImage: "circle.fill").foregroundColor(.red)
                Label("Shared", systemImage: "circle.fill").foregroundColor(.green)
            }
        }
        .listStyle(.sidebar)
    }
}

struct ViewLink: View {
    let title: String; let icon: String; let id: String
    @ObservedObject var vm: CalendarViewModel
    
    var body: some View {
        Button { vm.selectedView = id } label: {
            Label(title, systemImage: icon)
                .foregroundColor(vm.selectedView == id ? .blue : .primary)
        }
    }
}
