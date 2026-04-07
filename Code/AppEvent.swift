import Foundation
import SwiftUI
import UIKit

// gitMonk Interactive Shared Registry

public enum EventSource: String, Codable {
    case eventKit, reminders, local
}

public enum UnifiedAgendaItem: Identifiable {
    case event(AppEvent)
    case task(AppReminder)
    public var id: String { switch self { case .event(let e): return "e_" + e.id; case .task(let t): return "t_" + t.id } }
    public var sortDate: Date { switch self { case .event(let e): return e.startDate; case .task(let t): return t.dueDate ?? Date.distantFuture } }
}

// SHARED VIEW: FilterChipView
public struct FilterChipView: View {
    public let title: String; public let id: String; @Binding public var selectedID: String
    public init(title: String, id: String, selectedID: Binding<String>) {
        self.title = title; self.id = id; self._selectedID = selectedID
    }
    public var body: some View {
        Button(title) { selectedID = id }
            .font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 6)
            .background(selectedID == id ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(selectedID == id ? .white : .primary).cornerRadius(12)
    }
}

// SHARED VIEW: LiveTimeIndicator
public struct LiveTimeIndicator: View {
    public let width: CGFloat
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    public init(width: CGFloat) { self.width = width }
    private var offset: CGFloat {
        let cal = Foundation.Calendar.current
        let mins = Double(cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now))
        return CGFloat((mins / 60.0) * Double(DesignSystem.Layout.timelineHourHeight))
    }
    public var body: some View {
        HStack(spacing: 0) { Circle().fill(Color.red).frame(width: 6, height: 6); Rectangle().fill(Color.red).frame(width: width - 6, height: 1.5) }
        .offset(y: offset - 3).onReceive(timer) { input in now = input }.zIndex(999)
    }
}

public struct EventTemplate: Identifiable, Codable {
    public let id: UUID; public var title: String; public var location: String?; public var notes: String?; public var duration: Int; public var colorHex: String?
    public init(id: UUID = UUID(), title: String, location: String? = nil, notes: String? = nil, duration: Int = 60, colorHex: String? = nil) {
        self.id = id; self.title = title; self.location = location; self.notes = notes; self.duration = duration; self.colorHex = colorHex
    }
}

public enum RecurrenceType: String, CaseIterable, Identifiable, Codable {
    case none, daily, weekly, monthly, yearly
    public var id: String { rawValue }; public var displayName: String { rawValue.capitalized }
}

public struct AppEvent: Identifiable, Hashable, Codable {
    public let id: String; public var title: String; public var startDate: Date; public var endDate: Date; public var isAllDay: Bool; public var location: String?; public var notes: String?; public var alarms: [TimeInterval]; public var recurrence: RecurrenceType; public var source: EventSource; public var calendarID: String; public var colorHex: String; public var customColorHex: String?; public var isBirthday: Bool
    public init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date, isAllDay: Bool = false, location: String? = nil, notes: String? = nil, alarms: [TimeInterval] = [], recurrence: RecurrenceType = .none, source: EventSource = .local, calendarID: String, colorHex: String = "#007AFF", customColorHex: String? = nil, isBirthday: Bool = false) {
        self.id = id; self.title = title; self.startDate = startDate; self.endDate = endDate; self.isAllDay = isAllDay; self.location = location; self.notes = notes; self.alarms = alarms; self.recurrence = recurrence; self.source = source; self.calendarID = calendarID; self.colorHex = colorHex; self.customColorHex = customColorHex; self.isBirthday = isBirthday
    }
    public var displayColor: Color { if let custom = customColorHex, let c = Color(custom) { return c }; return Color(colorHex) ?? .blue }
    public var durationInMinutes: Int { (Foundation.Calendar.current.dateComponents([.minute], from: startDate, to: endDate)).minute ?? 0 }
    public func overlaps(with other: AppEvent) -> Bool { if isAllDay || other.isAllDay { return false }; return startDate < other.endDate && other.startDate < endDate }
}

public struct AppReminder: Identifiable, Hashable {
    public let id: String; public var title: String; public var dueDate: Date?; public var notes: String?; public var isCompleted: Bool; public var listID: String; public var colorHex: String; public var priority: Int
    public var displayColor: Color { Color(colorHex) ?? .green }
}

extension Color {
    init?(_ hex: String) {
        var hs = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hs.hasPrefix("#") { hs.remove(at: hs.startIndex) }
        var rgb: UInt64 = 0; guard Scanner(string: hs).scanHexInt64(&rgb) else { return nil }
        self.init(red: Double((rgb & 0xFF0000) >> 16) / 255.0, green: Double((rgb & 0x00FF00) >> 8) / 255.0, blue: Double(rgb & 0x0000FF) / 255.0)
    }
    func toHex() -> String? {
        let uic = UIColor(self); var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        if uic.getRed(&r, green: &g, blue: &b, alpha: &a) { return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255)) }
        return nil
    }
}
