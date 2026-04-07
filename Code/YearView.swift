import SwiftUI

struct YearView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let year = Calendar.current.component(.year, from: Date())

    private var months: [(Date, Int)] {
        (0..<12).map { monthIndex in
            let start = Calendar.current.date(from: DateComponents(year: year, month: monthIndex+1, day: 1))!
            let count = viewModel.groupedEvents.values.flatMap { $0 }.filter {
                Calendar.current.component(.year, from: $0.startDate) == year
            }.count
            return (start, count)
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                // Renamed tuple variables to prevent property access collisions
                ForEach(months, id: \.0) { monthDate, eventCount in
                    Rectangle()
                        .fill(Color.blue.opacity(max(0.1, Double(eventCount) / 10.0)))
                        // Added the required .dateTime prefix for the format style
                        .overlay(Text(monthDate.formatted(.dateTime.month(.abbreviated))).foregroundColor(.white).bold())
                        .frame(height: 100)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}
