import SwiftUI
import Foundation

struct YearView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    // FIXED: Resolved namespace collision
    private var currentYear: Int {
        return Foundation.Calendar.current.component(.year, from: Date())
    }

    private var months: [(Date, Int)] {
        (0..<12).map { monthIndex in
            let start = Foundation.Calendar.current.date(from: DateComponents(year: currentYear, month: monthIndex+1, day: 1))!
            let count = viewModel.groupedEvents.values.flatMap { $0 }.filter {
                Foundation.Calendar.current.component(.year, from: $0.startDate) == currentYear
            }.count
            return (start, count)
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(months, id: \.0) { monthDate, eventCount in
                    // Feature: Logarithmic scaling by gitMonk Interactive
                    let heatOpacity: Double = eventCount == 0 ? 0.05 : min(0.1 + (Double(eventCount) / 8.0), 0.9)
                    
                    Rectangle()
                        .fill(Color.blue.opacity(heatOpacity))
                        .overlay(
                            VStack(spacing: 2) {
                                Text(monthDate.formatted(.dateTime.month(.abbreviated))).foregroundColor(.white).bold()
                                if eventCount > 0 {
                                    Text("\(eventCount)").font(.system(size: 10)).foregroundColor(.white.opacity(0.8))
                                }
                            }
                        )
                        .frame(height: 100)
                        .cornerRadius(8)
                        .onTapGesture {
                            viewModel.anchorDate = monthDate
                            viewModel.selectedView = "month"
                        }
                }
            }
            .padding()
        }
    }
}
