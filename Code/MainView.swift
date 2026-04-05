import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                // MAIN VIEW
                VStack(spacing: 0) {
                    if viewModel.selectedView == "month" {
                        MonthView(viewModel: viewModel)
                    } else {
                        MultiDayView(viewModel: viewModel)
                    }
                    
                    // BOTTOM SLIDER (for Multi-Day)
                    if viewModel.selectedView == "week" {
                        HStack {
                            Text("\(viewModel.daysToDisplay) Days").font(.caption2).bold()
                            Slider(value: Binding(get: { Double(viewModel.daysToDisplay) }, set: { viewModel.daysToDisplay = Int($0) }), in: 1...14, step: 1)
                        }
                        .padding().background(.ultraThinMaterial)
                    }
                }
                .navigationTitle("gitMonkCal")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.searchText)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { viewModel.isSidebarOpen.toggle() } label: { Image(systemName: "line.3.horizontal") }
                    }
                }
                
                // SIDEBAR OVERLAY
                if viewModel.isSidebarOpen {
                    Color.black.opacity(0.3).onTapGesture { viewModel.isSidebarOpen = false }
                    SidebarView(viewModel: viewModel).transition(.move(edge: .leading))
                }
                
                // FLOATING ADD BUTTON
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showingAddSheet = true } label: {
                            Image(systemName: "plus").font(.title.bold()).foregroundColor(.white).frame(width: 60, height: 60).background(Circle().fill(Color.blue).shadow(radius: 5))
                        }
                        .padding(25)
                    }
                }
            }
            .animation(.spring(), value: viewModel.isSidebarOpen)
        }
        .sheet(isPresented: $showingAddSheet) {
            EventEditView(viewModel: viewModel)
        }
    }
}
