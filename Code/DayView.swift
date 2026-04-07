import SwiftUI

struct DayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String
    @State private var selectedDate: Date = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Today") { selectedDate = Date() }.font(DesignSystem.Typography.header)
                Spacer()
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day())).font(DesignSystem.Typography.header)
            }
            .padding()
            Divider()

            if viewModel.isLoading {
                ProgressView()
            } else {
                let events = viewModel.groupedEvents[Calendar.current.startOfDay(for: selectedDate)]?.filter {
                    searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)
                } ?? []

                ScrollView {
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            ForEach(0..<24) { hour in
                                HStack {
                                    Text("\(hour, specifier: "%02d"):00")
                                        .font(DesignSystem.Typography.timeLabel)
                                        .frame(width: 50, alignment: .leading)
                                        .padding(.leading, DesignSystem.Layout.densePadding)
                                    Rectangle().fill(DesignSystem.Aesthetics.gridLine).frame(height: 0.5)
                                }
                                Rectangle().fill(Color.clear).frame(height: DesignSystem.Layout.timelineHourHeight)
                            }
                        }

                        ForEach(events) { event in
                            TimelineEventPill(event: event, columnWidth: UIScreen.main.bounds.width - 60, opacity: viewModel.eventOpacity)
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .refreshable { await viewModel.refreshData() }
    }
}
