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
        let daysToAddBefore = (weekday - 1 + 7) % 7  // Start Sunday
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

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(monthDays, id: \.self) { date in
                            let startOfDay = Calendar.current.startOfDay(for: date)
                            let eventsForDay = (viewModel.groupedEvents[startOfDay] ?? []).filter {
                                searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)
                            }
                            MonthDayCell(date: date, events: eventsForDay)
                        }
                    }
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .refreshable {
            await viewModel.refreshData()
        }
    }
}

struct MonthDayCell: View {
    let date: Date
    let events: [AppEvent]

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(dayNumber)
                .font(DesignSystem.Typography.header.weight(.medium))
                .foregroundColor(Calendar.current.isDateInToday(date) ? .white : .primary)
                .padding(4)
                .background(Calendar.current.isDateInToday(date) ? Color.blue : Color.clear)
                .clipShape(Circle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 2)
                .padding(.trailing, 2)

            ForEach(events) { event in
                EventPill(event: event)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 100, maxHeight: .infinity, alignment: .top)
        .border(DesignSystem.Aesthetics.gridLine, width: 0.25)
        .contentShape(Rectangle())
        .contextMenu {
            Button("New Event") { }
            Button("Go to Day") { }
            Divider()
            Button("Clear", role: .destructive) { }
        }
    }
}

struct EventPill: View {
    let event: AppEvent

    var body: some View {
        Text(event.title)
            .font(DesignSystem.Typography.eventPill)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, DesignSystem.Layout.microPadding)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(event.displayColor.opacity(0.2))
            .foregroundColor(event.displayColor)
            .cornerRadius(DesignSystem.Aesthetics.pillRadius)
            .padding(.horizontal, 1)
    }
}
