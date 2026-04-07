import SwiftUI

struct MonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let searchText: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var monthDays: [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = viewModel.firstDayOfWeek
        let components = calendar.dateComponents([.year, .month], from: viewModel.anchorDate)
        guard let startOfMonth = calendar.date(from: components) else { return [] }
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let daysToAddBefore = (weekday - calendar.firstWeekday + 7) % 7 
        let firstDay = calendar.date(byAdding: .day, value: -daysToAddBefore, to: startOfMonth)!
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: firstDay) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(monthDays, id: \.self) { date in
                    let events = viewModel.groupedEvents[Calendar.current.startOfDay(for: date)]?.filter {
                        searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)
                    } ?? []
                    MonthDayCell(date: date, events: events, opacity: viewModel.eventOpacity, viewModel: viewModel)
                }
            }
            Spacer()
        }
        .refreshable { await viewModel.refreshData() }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            let days = viewModel.firstDayOfWeek == 1 ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            ForEach(days, id: \.self) { day in
                Text(day).font(DesignSystem.Typography.timeLabel).foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 4).border(DesignSystem.Aesthetics.gridLine, width: 0.25)
            }
        }
    }
}

struct MonthDayCell: View {
    let date: Date; let events: [AppEvent]; let opacity: Double
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack {
                if isFirstDayOfDisplayWeek { Text("W\(currentWeekOfYear)").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary.opacity(0.5)).padding(.leading, 2) }
                Spacer()
                Text(date.formatted(.dateTime.day())).font(DesignSystem.Typography.monthDayNumber).foregroundColor(Calendar.current.isDateInToday(date) ? .white : .primary).padding(4).background(Calendar.current.isDateInToday(date) ? Color.blue : Color.clear).clipShape(Circle())
            }
            
            // Feature: BC2 glanceable busy-dots
            HStack(spacing: 2) {
                ForEach(events.prefix(4)) { event in
                    Circle().fill(event.displayColor).frame(width: 4, height: 4)
                }
                if events.count > 4 { Text("+").font(.system(size: 6)).foregroundColor(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)

            ForEach(events.prefix(3)) { event in
                HStack(spacing: 2) {
                    if event.isBirthday { Text("🎁").font(.system(size: 8)) }
                    Text(event.title).font(DesignSystem.Typography.eventPill).lineLimit(1)
                }
                .padding(.horizontal, 2).frame(maxWidth: .infinity, alignment: .leading).background(event.displayColor.opacity(opacity)).foregroundColor(event.displayColor).cornerRadius(2)
                .onTapGesture { viewModel.editingEvent = event }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 80, maxHeight: .infinity, alignment: .top).border(DesignSystem.Aesthetics.gridLine, width: 0.25).contentShape(Rectangle())
        .onTapGesture { viewModel.targetDateForNewItem = date; viewModel.isAddingNew = true }
    }

    private var isFirstDayOfDisplayWeek: Bool { var cal = Calendar.current; cal.firstWeekday = viewModel.firstDayOfWeek; return cal.component(.weekday, from: date) == cal.firstWeekday }
    private var currentWeekOfYear: Int { var cal = Calendar.current; cal.firstWeekday = viewModel.firstDayOfWeek; return cal.component(.weekOfYear, from: date) }
}
