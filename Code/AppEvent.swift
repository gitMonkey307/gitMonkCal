import Foundation
import SwiftUI

public enum EventSource: String, Codable {
    case eventKit, reminders, local
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
    public var hasAlarms: Bool
    public var source: EventSource
    public var calendarID: String
    public var colorHex: String 

    public init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date, isAllDay: Bool = false, location: String? = nil, notes: String? = nil, hasAlarms: Bool = false, source: EventSource = .local, calendarID: String, colorHex: String = "#007AFF") {
        self.id = id; self.title = title; self.startDate = startDate; self.endDate = endDate; self.isAllDay = isAllDay; self.location = location; self.notes = notes; self.hasAlarms = hasAlarms; self.source = source; self.calendarID = calendarID; self.colorHex = colorHex
    }

    public var displayColor: Color { Color(hex: colorHex) ?? .blue }
    
    public var durationInMinutes: Int {
        let components = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
        return components.minute ?? 0
    }
}

public struct AppReminder: Identifiable, Hashable {
    public let id: String
    public var title: String
    public var dueDate: Date?
    public var isCompleted: Bool
    public var listID: String
    public var colorHex: String
    
    public var displayColor: Color { Color(hex: colorHex) ?? .green }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") { hexSanitized.remove(at: hexSanitized.startIndex) }
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        self.init(red: Double((rgb & 0xFF0000) >> 16) / 255.0, green: Double((rgb & 0x00FF00) >> 8) / 255.0, blue: Double(rgb & 0x0000FF) / 255.0)
    }
}
