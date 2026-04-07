struct MonthDayCell: View {
    let date: Date; let events: [AppEvent]; let opacity: Double; @ObservedObject var viewModel: CalendarViewModel

    // FIXED: Extracted logic into computed properties
    private var weekOfYear: Int {
        var cal = Calendar.current
        cal.firstWeekday = viewModel.firstDayOfWeek
        return cal.component(.weekOfYear, from: date)
    }

    private var isFirstDayOfDisplayWeek: Bool {
        var cal = Calendar.current
        cal.firstWeekday = viewModel.firstDayOfWeek
        return cal.component(.weekday, from: date) == cal.firstWeekday
    }

    private var isWeekend: Bool {
        let day = Calendar.current.component(.weekday, from: date)
        return day == 1 || day == 7
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack {
                if isFirstDayOfDisplayWeek {
                    Text("W\(weekOfYear)").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary.opacity(0.5)).padding(.leading, 2)
                }
                Spacer()
                Text(date.formatted(.dateTime.day()))
                    .font(viewModel.isHighDensity ? .system(size: 9) : DesignSystem.Typography.monthDayNumber)
                    .foregroundColor(Calendar.current.isDateInToday(date) ? .white : (isWeekend ? .secondary : .primary))
                    .padding(4).background(Calendar.current.isDateInToday(date) ? Color.blue : Color.clear).clipShape(Circle())
            }
            
            HStack(spacing: 2) {
                ForEach(events.prefix(4)) { event in Circle().fill(event.displayColor).frame(width: 3, height: 3) }
            }
            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 2)

            ForEach(events.prefix(viewModel.isHighDensity ? 5 : 3)) { event in
                Text(event.title).font(.system(size: viewModel.isHighDensity ? 7 : 9, weight: .bold)).lineLimit(1)
                    .padding(.horizontal, 2).frame(maxWidth: .infinity, alignment: .leading).background(event.displayColor.opacity(opacity)).foregroundColor(event.displayColor).cornerRadius(2)
                    .onTapGesture { viewModel.editingEvent = event }
            }
            Spacer(minLength: 0)
        }
        .background(isWeekend ? Color.secondary.opacity(0.05) : Color.clear)
        .frame(minHeight: 80, maxHeight: .infinity, alignment: .top).border(DesignSystem.Aesthetics.gridLine, width: 0.25).contentShape(Rectangle())
        .onTapGesture { viewModel.targetDateForNewItem = date; viewModel.isAddingNew = true }
    }
}
