import SwiftUI

struct MonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var monthDays: [Date] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: viewModel.anchorDate)
        guard let startOfMonth = calendar.date(from: components) else { return [] }
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let daysToAddBefore = (weekday - 1 + 7) % 7 
        let firstDay = calendar.date(byAdding: .day, value: -daysToAddBefore, to: startOfMonth)!
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: firstDay) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(DesignSystem.Typography.timeLabel)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Layout.densePadding)
                        .border(DesignSystem.Aesthetics.gridLine, width: 0.25)
                }
            }

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(monthDays, id: \.self) { date in
                    let events = viewModel.groupedEvents[Calendar.current.startOfDay(for: date)]?.filter {
                        searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)
                    } ?? []
                    MonthDayCell(date: date, events: events)
                }
            }
            Spacer()
        }
    }
}

struct MonthDayCell: View {
    let date: Date
    let events: [AppEvent]

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(date.formatted(.dateTime.day()))
                .font(DesignSystem.Typography.monthDayNumber)
                .foregroundColor(Calendar.current.isDateInToday(date) ? .white : .primary)
                .padding(4)
                .background(Calendar.current.isDateInToday(date) ? Color.blue : Color.clear)
                .clipShape(Circle())
                .frame(maxWidth: .infinity, alignment: .trailing)

            ForEach(events) { event in
                Text(event.title)
                    .font(DesignSystem.Typography.eventPill)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(event.displayColor.opacity(0.3))
                    .foregroundColor(event.displayColor)
                    .cornerRadius(2)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 80, maxHeight: .infinity, alignment: .top)
        .border(DesignSystem.Aesthetics.gridLine, width: 0.25)
    }
}
