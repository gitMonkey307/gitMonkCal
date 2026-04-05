import SwiftUI
import WeatherKit

struct DayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let date: Date
    @State private var weather: Weather? // WeatherKit
    @State private var isLoadingWeather = false

    var events: [AppEvent] { viewModel.groupedEvents[Calendar.current.startOfDay(for: date)] ?? [] }
    var tasks: [AppEvent] { viewModel.remindersForDay(date) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(DesignSystem.Typography.header)
                .padding()

            // Weather
            if let weather = weather {
                HStack {
                    Image(systemName: weatherSymbol(for: weather.currentWeather.condition))
                    VStack(alignment: .leading) {
                        Text("\(Int(weather.currentWeather.temperature.value))°")
                            .font(.largeTitle)
                        Text(weather.currentWeather.condition.category.description)
                            .font(DesignSystem.Typography.body)
                    }
                }
                .padding()
                .background(DesignSystem.Aesthetics.toolbarMaterial)
            }

            Divider()

            // Timeline (reuse DayColumn logic)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(events) { event in
                        TimelineEventPill(event: event, columnWidth: UIScreen.main.bounds.width - DesignSystem.Layout.screenEdge * 2)
                    }
                    // Tasks/Birthdays
                    Section {
                        ForEach(tasks) { task in
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.orange)
                                    .frame(width: 4)
                                Text(task.title)
                                    .font(DesignSystem.Typography.eventPill)
                                Spacer()
                                if task.isCompleted { Image(systemName: "checkmark.circle.fill") }
                            }
                            .padding(.horizontal)
                        }
                    } header: {
                        Text("Tasks & Birthdays")
                            .font(DesignSystem.Typography.header)
                    }
                }
            }
        }
        .refreshable { await viewModel.refreshData() }
        .task { await loadWeather() }
    }

    private func loadWeather() async {
        isLoadingWeather = true
        // WeatherKit example (requires location perms)
        do {
            let service = WeatherService.shared
            let loc = CLLocation(latitude: 37.7749, longitude: -122.4194) // SF demo
            weather = try await service.weather(for: loc, including: .current)
        } catch {}
        isLoadingWeather = false
    }

    private func weatherSymbol(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear: return "sun.max"
        case .cloudy: return "cloud"
        default: return "cloud.sun"
        }
    }
}
