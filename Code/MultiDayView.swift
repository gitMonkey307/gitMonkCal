import SwiftUI

struct MultiDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let numberOfDays: Int
    let searchText: String

    @State private var scrollOffset: CGFloat = 0
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var visibleDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: Int(scrollOffset / 100), to: today) ?? today
        return (0..<numberOfDays).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let columnWidth = screenWidth / CGFloat(numberOfDays)

            ZStack(alignment: .bottom) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(viewModel.dateRangeArray, id: \.self) { date in
                            let events = viewModel.groupedEvents[date]?.filter {
                                searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)
                            } ?? []
                            DayColumn(date: date, events: events, width: columnWidth)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)

                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 20) {
                        Image(systemName: DesignSystem.Icons.sliderSettings)
                            .foregroundColor(.secondary)
                        Text("\(numberOfDays) Days")
                            .font(DesignSystem.Typography.timeLabel)
                            .monospacedDigit()
                            .frame(width: 45)
                    }
                    .padding(.horizontal, DesignSystem.Layout.screenEdge)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Aesthetics.toolbarMaterial)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .refreshable {
            await viewModel.refreshData()
        }
    }
}

struct DayColumn: View {
    let date: Date
    let events: [AppEvent]
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(date.formatted(.dateFormat: .abbreviatedName))
                    .font(DesignSystem.Typography.timeLabel)
                    .foregroundColor(.secondary)
                Text(date.formatted(.dateFormat: .numeric))
                    .font(DesignSystem.Typography.header)
                    .foregroundColor(Calendar.current.isDateInToday(date) ? .blue : .primary)
            }
            .padding(.vertical, 8)
            .frame(width: width)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.3))

            Divider()

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    ForEach(0..<24) { hour in
                        Rectangle()
                            .fill(DesignSystem.Aesthetics.gridLine)
                            .frame(height: 0.5)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .frame(height: DesignSystem.Layout.timelineHourHeight)
                    }
                }

                ForEach(events) { event in
                    TimelineEventPill(event: event, columnWidth: width)
                }
            }
        }
        .frame(width: width)
        .border(DesignSystem.Aesthetics.gridLine, width: 0.25)
    }
}

struct TimelineEventPill: View {
    let event: AppEvent
    let columnWidth: CGFloat

    var body: some View {
        if !event.isAllDay {
            let calendar = Calendar.current
            let startMinutes = CGFloat(calendar.component(.hour, from: event.startDate) * 60 + calendar.component(.minute, from: event.startDate))
            let duration = CGFloat(event.durationInMinutes)
            let topOffset = (startMinutes / 60.0) * DesignSystem.Layout.timelineHourHeight
            let height = max((duration / 60.0) * DesignSystem.Layout.timelineHourHeight, 20)

            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(DesignSystem.Typography.eventPill)
                    .fontWeight(.bold)
                if height > 30 {
                    Text(event.startDate, style: .time)
                        .font(DesignSystem.Typography.timeLabel)
                        .opacity(0.8)
                }
            }
            .padding(4)
            .frame(width: columnWidth - 4, height: height, alignment: .topLeading)
            .background(event.displayColor.opacity(0.2))
            .foregroundColor(event.displayColor)
            .cornerRadius(DesignSystem.Aesthetics.pillRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Aesthetics.pillRadius)
                    .stroke(event.displayColor.opacity(0.5), lineWidth: 1)
            )
            .offset(y: topOffset)
            .padding(.horizontal, 2)
        }
    }
}
