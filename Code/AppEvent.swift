import SwiftUI

public struct AppEvent: Identifiable, Hashable {
    public let id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?
    public var colorHex: String
    public var isTask: Bool
    public var isCompleted: Bool = false
    public var calendarID: String
    
    public var displayColor: Color { Color(hex: colorHex) ?? .blue }
}
