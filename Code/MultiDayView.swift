import SwiftUI
import Foundation

struct MultiDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader { geometry in
            // FIXED: Explicit unboxing of the Published property
            let displayVal = CGFloat(viewModel.daysToDisplay)
            let columnWidth = geometry.size.width / max(1.0, displayVal)

            ZStack(alignment: .bottom) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(viewModel.dateRangeArray, id: \.self) { date in
                            let events = viewModel.groupedEvents[Foundation.Calendar.current.startOfDay(for: date)]?.filter {
                                viewModel.searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(viewModel.searchText)
                            } ?? []
                            DayColumnView(date: date, events: events, width: columnWidth, opacity: viewModel.eventOpacity, viewModel: viewModel)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                sliderControl
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var sliderControl: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 15) {
                // FIXED: Explicitly stringified for the compiler
                Text("\(Int(viewModel.daysToDisplay)) Days").font(DesignSystem.Typography.timeLabel).monospacedDigit().frame(width: 60)
                
                Slider(value: Binding(
                    get: { Double(viewModel.daysToDisplay) },
                    set: { viewModel.daysToDisplay = Int($0); haptic.selectionChanged() }
                ), in: 1...14, step: 1)
            }
            .padding(.horizontal, DesignSystem.Layout.screenEdge).padding(.vertical, 8).background(.ultraThinMaterial)
        }
    }
}

struct DayColumnView: View {
    let date: Date; let events: [AppEvent]; let width: CGFloat; let opacity: Double; @ObservedObject var viewModel: CalendarViewModel
    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.weekday(.abbreviated))).font(.caption).bold()
            Text(date.formatted(.dateTime.day())).font(.caption2)
            Divider().padding(.vertical, 4)
            ZStack(alignment: .top) {
                ForEach(events) { event in 
                    let overlapping = events.filter { $0.overlaps(with: event) }.sorted { $0.startDate < $1.startDate }
                    let myIndex = overlapping.firstIndex(where: { $0.id == event.id }) ?? 0
                    let sharedWidth = width / CGFloat(max(1, overlapping.count))
                    TimelineEventPill(event: event, columnWidth: sharedWidth, opacity: opacity, viewModel: viewModel).offset(x: CGFloat(myIndex) * sharedWidth)
                }
                // FIXED: Now sees globally visible LiveTimeIndicator
                if Foundation.Calendar.current.isDateInToday(date) { LiveTimeIndicator(width: width) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: width).border(DesignSystem.Aesthetics.gridLine, width: 0.5)
    }
}

struct TimelineEventPill: View {
    let event: AppEvent; let columnWidth: CGFloat; let opacity: Double; @ObservedObject var viewModel: CalendarViewModel
    private var geometry: (top: CGFloat, height: CGFloat) {
        let cal = Foundation.Calendar.current
        let startMins = Double(cal.component(.hour, from: event.startDate) * 60 + cal.component(.minute, from: event.startDate))
        let durationMins = Double(event.durationInMinutes)
        let hourHeight = Double(DesignSystem.Layout.timelineHourHeight)
        return (CGFloat((startMins / 60.0) * hourHeight), CGFloat(max((durationMins / 60.0) * hourHeight, 20.0)))
    }
    var body: some View {
        if !event.isAllDay {
            VStack(alignment: .leading, spacing: 0) { Text(event.title).font(.system(size: 8, weight: .bold)).lineLimit(1) }
            .padding(2).frame(width: max(10, columnWidth - 2), height: geometry.height, alignment: .topLeading)
            .background(event.displayColor.opacity(opacity)).foregroundColor(event.displayColor).cornerRadius(2)
            .offset(y: geometry.top).contentShape(Rectangle()).onTapGesture { viewModel.editingEvent = event }
        }
    }
}
