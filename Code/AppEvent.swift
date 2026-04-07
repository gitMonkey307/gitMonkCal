import Foundation
import SwiftUI

public enum EventSource: String, Codable {
    case eventKit, reminders, local
}

// NEW: For BC2 Quick-Entry workflow
public struct EventTemplate: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var location: String?
    public var notes: String?
    public var duration: Int
    public var colorHex: String?
    
    public init(id: UUID = UUID(), title: String, location: String? = nil, notes: String? = nil, duration: Int = 60, colorHex: String? = nil) {
        self.id = id; self.title = title; self.location = location; self.notes = notes; self.duration = duration; self.colorHex = colorHex
    }
}

public enum RecurrenceType: String, CaseIterable, Identifiable, Codable {
    case none, daily, weekly, monthly, yearly
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public struct AppEvent: Identifiable, Hashable, Codable {
    public let id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?
    public var alarms: [TimeInterval]
    public var recurrence: RecurrenceType
    public var source: EventSource
    public var calendarID: String
    public var colorHex: String 
    public var customColorHex: String? // Feature: Override Calendar Color
    public var isBirthday: Bool

    public init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date, isAllDay: Bool = false, location: String? = nil, notes: String? = nil, alarms: [TimeInterval] = [], recurrence: RecurrenceType = .none, source: EventSource = .local, calendarID: String, colorHex: String = "#007AFF", customColorHex: String? = nil, isBirthday: Bool = false) {
        self.id = id; self.title = title; self.startDate = startDate; self.endDate = endDate; self.isAllDay = isAllDay; self.location = location; self.notes = notes; self.alarms = alarms; self.recurrence = recurrence; self.source = source; self.calendarID = calendarID; self.colorHex = colorHex; self.customColorHex = customColorHex; self.isBirthday = isBirthday
    }

    public var displayColor: Color {
        if let custom = customColorHex { return Color(hex: custom) ?? Color(hex: colorHex) ?? .blue }
        return Color(hex: colorHex) ?? .blue
    }
    
    public var durationInMinutes: Int {
        let components = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
        return components.minute ?? 0
    }
}

public struct AppReminder: Identifiable, Hashable {
    public let id: String
    public var title: String
    public var dueDate: Date?
    public var notes: String?
    public var isCompleted: Bool
    public var listID: String
    public var colorHex: String
    public var priority: Int
    public var displayColor: Color { Color(hex: colorHex) ?? .green }
}
