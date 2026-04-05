// Add to Settings tab or separate if needed
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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
            ForEach(months, id: \.0) { month, count in
                Rectangle()
                    .fill(Color.blue.opacity(Double(count) / 10.0))
                    .overlay(
                        Text(month.0.formatted(.month(.abbreviated)))
                            .foregroundColor(.white)
                    )
                    .frame(height: 100)
            }
        }
    }
}
