import AppIntents
import EventKit
import SwiftUI
import Foundation

public struct CalendarShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateEventIntent(),
            phrases: ["Add an event in \(.applicationName)"],
            shortTitle: "New Event",
            systemImageName: "calendar.badge.plus"
        )
    }
}

public struct CreateEventIntent: AppIntent {
    public static var title: LocalizedStringResource = "Create Calendar Event"

    @Parameter(title: "Event Title")
    public var title: String

    @Parameter(title: "Start Date")
    public var startDate: Date

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        let manager = EventKitManager()
        do {
            try await manager.requestCalendarAccess()
            let endDate = startDate.addingTimeInterval(3600)
            let defaultCalID = manager.store.defaultCalendarForNewEvents?.calendarIdentifier ?? ""
            
            try await manager.saveEvent(
                id: nil, title: title, start: startDate, end: endDate,
                isAllDay: false, location: nil, notes: "Created via gitMonk Interactive Siri",
                calendarID: defaultCalID, alarms: [], recurrenceType: .none
            )
            return .result(dialog: "Added \(title) to your calendar by gitMonk Interactive.")
        } catch {
            return .result(dialog: "Failed to access calendar. Please check gitMonk Interactive permissions.")
        }
    }
}
