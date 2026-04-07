import SwiftUI
import Foundation

struct MultiDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader { geometry in
            // FIXED: Explicitly casting values to prevent compiler timeout
            let displayCount = CGFloat(max(1, viewModel.daysToDisplay))
            let columnWidth = geometry.size.width / displayCount

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
                Text("\(viewModel.daysToDisplay) Days").font(DesignSystem.Typography.timeLabel).monospacedDigit().frame(width: 50)
                Slider(value: Binding(get: { Double(viewModel.daysToDisplay) }, set: { viewModel.daysToDisplay = Int($0); haptic.impactOccurred() }), in: 1...14, step: 1)
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
                    TimelineEventPill(event: event, columnWidth: width, opacity: opacity, viewModel: viewModel) 
                }
                
                // FIXED: Resolved namespace collision
                if Foundation.Calendar.current.isDateInToday(date) { 
                    LiveTimeIndicator(width: width) 
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: width).border(DesignSystem.Aesthetics.gridLine, width: 0.5)
    }
}
