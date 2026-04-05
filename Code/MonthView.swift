import SwiftUI

struct MonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let days = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(days, id: \.self) { day in
                    Text(day).font(.caption2).bold().frame(maxWidth: .infinity)
                }
            }
            GeometryReader { geo in
                let cellWidth = geo.size.width / 7
                let cellHeight = geo.size.height / 5
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(0..<35, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(i+1)").font(DesignSystem.Typography.monthDayNumber).padding(2)
                            // Event bars go here
                        }
                        .frame(width: cellWidth, height: cellHeight, alignment: .topLeading)
                        .border(Color.gray.opacity(0.1), width: 0.5)
                    }
                }
            }
        }
    }
}
