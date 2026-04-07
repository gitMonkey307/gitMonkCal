import SwiftUI

struct YearView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let year = Calendar.current.component(.year, from: Date())

    private var months: [(Date, Int)] {
        (0..<12).map { month in
            let start = Calendar.current.date(from: DateComponents(year: year, month: month+1, day: 1))!
            let count = viewModel.groupedEvents.values.flatMap { $0 }.filter {
                Calendar.current.component(.year, from: $0.startDate) == year
            }.count
            return (start, count)
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(months, id: \.0) { month, count in
                    Rectangle()
                        .fill(Color.blue.opacity(max(0.1, Double(count) / 10.0)))
                        // Removed the .0 member to fix the format casting error
                        .overlay(Text(month.formatted(.month(.abbreviated))).foregroundColor(.white).bold())
                        .frame(height: 100)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}
