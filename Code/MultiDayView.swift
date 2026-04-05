import SwiftUI

public struct MultiDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    // MARK: - State
    @State private var numberOfDays: Int = 3 // BC2 default is often 3 or 5
    @State private var scrollOffset: CGFloat = 0
    
    // Haptic feedback generator for the slider
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    public var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let columnWidth = screenWidth / CGFloat(numberOfDays)
            
            ZStack(alignment: .bottom) {
                // 1. The High-Density Horizontal Timeline
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        // We render a window of days based on the ViewModel's range
                        ForEach(viewModel.dateRangeArray, id: \.self) { date in
                            DayColumn(
                                date: date,
                                events: viewModel.groupedEvents[date] ?? [],
                                width: columnWidth
                            )
                        }
                    }
                    .scrollTargetLayout()
                }
                // iOS 17+ Paging: This ensures the scroll snaps to the start of the first visible day
                .scrollTargetBehavior(.paging)
                
                // 2. The BC2-Style Bottom Toolbar
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 20) {
                        Image(systemName: DesignSystem.Icons.sliderSettings)
                            .foregroundColor(.secondary)
                        
                        // Native SwiftUI Slider with Haptic Integration
                        Slider(value: Binding(
                            get: { Double(numberOfDays) },
                            set: { newValue in
                                let rounded = Int(newValue)
                                if rounded != numberOfDays {
                                    numberOfDays = rounded
                                    haptic.impactOccurred() // The physical "click"
                                }
                            }
                        ), in: 1...14, step: 1)
                        .tint(.blue)
                        
                        Text("\(numberOfDays) Days")
                            .font(DesignSystem.Typography.timeLabel)
                            .monospacedDigit()
                            .frame(width: 45)
                    }
                    .padding(.horizontal, DesignSystem.Layout.screenEdge)
                    .padding(.vertical, 12)
                    // Apply the iOS-native material blur requested
                    .background(DesignSystem.Aesthetics.toolbarMaterial)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Day Column Component
struct DayColumn: View {
    let date: Date
    let events: [AppEvent]
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            // Day Header (Date and Name)
            VStack(spacing: 2) {
                Text(date.formatAsDayName()) // e.g., "MON"
                    .font(DesignSystem.Typography.timeLabel)
                    .foregroundColor(.secondary)
                
                Text(date.formatAsDayNumber()) // e.g., "12"
                    .font(DesignSystem.Typography.header)
                    .foregroundColor(Calendar.current.isDateInToday(date) ? .blue : .primary)
            }
            .padding(.vertical, 8)
            .frame(width: width)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.3))
            
            Divider()
            
            // The Timeline Grid
            ZStack(alignment: .top) {
                // Background Hour Lines (The BC2 "Skeleton")
                VStack(spacing: 0) {
                    ForEach(0..<24) { hour in
                        Rectangle()
                            .fill(DesignSystem.Aesthetics.gridLine)
                            .frame(height: 0.5)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .frame(height: DesignSystem.Layout.timelineHourHeight)
                    }
                }
                
                // Events overlaid on the timeline
                ForEach(events) { event in
                    TimelineEventPill(event: event, columnWidth: width)
                }
            }
        }
        .frame(width: width)
        .border(DesignSystem.Aesthetics.gridLine, width: 0.25)
    }
}

// MARK: - Timeline Event Pill
struct TimelineEventPill: View {
    let event: AppEvent
    let columnWidth: CGFloat
    
    var body: some View {
        if !event.isAllDay {
            let startMinutes = CGFloat(Calendar.current.component(.hour, from: event.startDate) * 60 + Calendar.current.component(.minute, from: event.startDate))
            let duration = CGFloat(event.durationInMinutes)
            let topOffset = (startMinutes / 60.0) * DesignSystem.Layout.timelineHourHeight
            let height = (duration / 60.0) * DesignSystem.Layout.timelineHourHeight
            
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(DesignSystem.Typography.eventPill)
                    .fontWeight(.bold)
                if height > 30 { // Only show time if the block is large enough
                    Text(event.startDate, style: .time)
                        .font(DesignSystem.Typography.timeLabel)
                        .opacity(0.8)
                }
            }
            .padding(4)
            .frame(width: columnWidth - 4, height: max(height, 20), alignment: .topLeading)
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

// MARK: - Date Helpers
extension Date {
    func formatAsDayName() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: self).uppercased()
    }
    
    func formatAsDayNumber() -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: self)
    }
}

extension CalendarViewModel {
    /// Helper to generate a flat list of dates for the horizontal ScrollView
    var dateRangeArray: [Date] {
        var dates: [Date] = []
        var current = currentViewRange.start
        while current <= currentViewRange.end {
            dates.append(current)
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        }
        return dates
    }
}