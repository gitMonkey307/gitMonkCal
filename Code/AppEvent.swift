import Foundation
import SwiftUI

// MARK: - Event Source Enumeration
/// Defines exactly where the data originated, dictating how we sync changes back.
public enum EventSource: String, Codable {
    case eventKit     // Apple Calendar, Exchange, iCloud
    case googleTasks  // Direct REST API sync
    case local        // App-specific drafts or disconnected events
}

// MARK: - AppEvent Model
/// The unified data model representing a single block of time or task.
public struct AppEvent: Identifiable, Hashable, Codable {
    
    /// Unique identifier (Maps to EventKit's eventIdentifier or Google's Task ID)
    public let id: String
    
    // MARK: Core Data
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    
    // MARK: Contextual Details
    public var location: String?
    public var notes: String?
    public var hasAlarms: Bool
    
    // MARK: Sync & Rendering Metadata
    public var source: EventSource
    public var calendarID: String
    /// Stored as a hex string for safe Codable conformance, mapped to Color via an extension
    public var colorHex: String 
    
    // MARK: - Initialization
    public init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        hasAlarms: Bool = false,
        source: EventSource = .local,
        calendarID: String,
        colorHex: String = "#007AFF" // Default iOS Blue
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.hasAlarms = hasAlarms
        self.source = source
        self.calendarID = calendarID
        self.colorHex = colorHex
    }
}

// MARK: - Convenience Extensions
extension AppEvent {
    /// Safely converts the stored hex string back into an iOS-native SwiftUI Color.
    var displayColor: Color {
        Color(hex: colorHex) ?? Color.blue
    }
    
    /// Calculates duration in minutes (Useful for dynamic UI height calculations in timeline views)
    var durationInMinutes: Int {
        let components = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
        return components.minute ?? 0
    }
}

// MARK: - Color Hex Helper
// A standard helper to translate hex codes for safe data persistence.
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}