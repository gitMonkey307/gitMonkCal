import Foundation
import SwiftUI

public enum EventSource: String, Codable {
    case eventKit, reminders, local
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
