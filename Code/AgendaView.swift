import SwiftUI

struct AgendaView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String

    private var upcomingEvents: [AppEvent] {
        let filtered = viewModel.groupedEvents.values.flatMap { $0 }.filter {
            $0.startDate >= Date() && (searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText))
        }.sorted { $0.startDate < $1.startDate }
        
        return Array(filtered.prefix(100))
    }

    var body: some View {
        List {
            ForEach(upcomingEvents, id: \.id) { event in
                VStack(alignment: .leading, spacing: DesignSystem.Layout.densePadding) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(event.displayColor).frame(width: 4)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(event.title).font(DesignSystem.Typography.eventPill).lineLimit(1)
                            Text(event.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                                .font(DesignSystem.Typography.timeLabel).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.editingEvent = event }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refreshData() }
    }
}
