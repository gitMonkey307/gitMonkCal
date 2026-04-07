import SwiftUI

struct MultiDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var scrollOffset: CGFloat = 0
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width / CGFloat(viewModel.daysToDisplay)

            ZStack(alignment: .bottom) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(viewModel.dateRangeArray, id: \.self) { date in
                            let events = viewModel.groupedEvents[date]?.filter {
                                viewModel.searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(viewModel.searchText)
                            } ?? []
                            DayColumn(date: date, events: events, width: columnWidth, opacity: viewModel.eventOpacity)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)

                // THE BC2 SLIDER
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 15) {
                        Text("\(viewModel.daysToDisplay) Days")
                            .font(DesignSystem.Typography.timeLabel)
                            .monospacedDigit()
                            .frame(width: 50)
                        
                        Slider(value: Binding(
                            get: { Double(viewModel.daysToDisplay) },
                            set: { viewModel.daysToDisplay = Int($0); haptic.impactOccurred() }
                        ), in: 1...14, step: 1)
                    }
                    .padding(.horizontal, DesignSystem.Layout.screenEdge)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

struct DayColumn: View {
    let date: Date
    let events: [AppEvent]
    let width: CGFloat
    let opacity: Double

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.weekday(.abbreviated))).font(.caption).bold()
            Text(date.formatted(.dateTime.day())).font(.caption2)
            Divider().padding(.vertical, 4)
            
            ZStack(alignment: .top) {
                ForEach(events) { event in
                    TimelineEventPill(event: event, columnWidth: width, opacity: opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: width)
        .border(DesignSystem.Aesthetics.gridLine, width: 0.5)
    }
}

struct TimelineEventPill: View {
    let event: AppEvent
    let columnWidth: CGFloat
    let opacity: Double

    var body: some View {
        if !event.isAllDay {
            let cal = Calendar.current
            let startMins = CGFloat(cal.component(.hour, from: event.startDate) * 60 + cal.component(.minute, from: event.startDate))
            let duration = CGFloat(event.durationInMinutes)
            let topOffset = (startMins / 60.0) * DesignSystem.Layout.timelineHourHeight
            let height = max((duration / 60.0) * DesignSystem.Layout.timelineHourHeight, 20)

            VStack(alignment: .leading, spacing: 0) {
                Text(event.title).font(DesignSystem.Typography.eventPill).fontWeight(.bold).lineLimit(1)
            }
            .padding(4)
            .frame(width: columnWidth - 4, height: height, alignment: .topLeading)
            .background(event.displayColor.opacity(opacity))
            .foregroundColor(event.displayColor)
            .cornerRadius(DesignSystem.Aesthetics.pillRadius)
            .offset(y: topOffset)
        }
    }
}
