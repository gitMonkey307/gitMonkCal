import SwiftUI

struct MultiDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        VStack {
            // The Timeline
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(0..<viewModel.daysToDisplay, id: \.self) { i in
                        VStack {
                            Text("Day \(i)").font(.caption).bold()
                            Divider()
                            Spacer()
                        }
                        .frame(width: UIScreen.main.bounds.width / CGFloat(min(viewModel.daysToDisplay, 5)))
                        .border(Color.gray.opacity(0.2), width: 0.5)
                    }
                }
            }
            
            // THE BC2 SLIDER
            VStack {
                Text("\(viewModel.daysToDisplay) Days").font(.caption2).bold()
                Slider(value: Binding(
                    get: { Double(viewModel.daysToDisplay) },
                    set: { viewModel.daysToDisplay = Int($0) }
                ), in: 1...14, step: 1)
                .padding(.horizontal)
            }
            .background(.ultraThinMaterial)
        }
    }
}
