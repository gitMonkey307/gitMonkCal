import Foundation
import EventKit
import SwiftUI

// MARK: - Error Handling
public enum EventKitError: LocalizedError {
    case accessDenied
    case restricted
    case fetchFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied: return "Calendar access was denied. Please enable it in Settings."
        case .restricted: return "Calendar access is restricted by parental controls or MDM."
        case .fetchFailed(let message): return "Failed to fetch events: \(message)"
        }
    }
}

// MARK: - EventKit Manager
/// A singleton manager responsible for all EventKit interactions.
/// Designed for safe concurrent access on iOS 17+.
@MainActor
public class EventKitManager: ObservableObject {
    
    /// The single shared instance of the event store, as recommended by Apple.
    private let store = EKEventStore()
    
    /// Published state so the UI can react if permissions change while the app is backgrounded.
    @Published public var isAuthorized: Bool = false
    
    public init() {
        checkInitialAuthorizationStatus()
    }
    
    // MARK: - Permissions (iOS 17+ Standard)
    
    /// Checks the current status without triggering a system prompt.
    private func checkInitialAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        self.isAuthorized = (status == .fullAccess || status == .authorized)
    }
    
    /// Requests full read/write access using modern iOS 17+ APIs.
    public func requestCalendarAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .notDetermined:
            // iOS 17+ requires explicit Full Access or Write Only. We need Full.
            let granted = try await store.requestFullAccessToEvents()
            self.isAuthorized = granted
            if !granted { throw EventKitError.accessDenied }
            
        case .restricted:
            throw EventKitError.restricted
            
        case .denied:
            throw EventKitError.accessDenied
            
        case .fullAccess, .authorized:
            self.isAuthorized = true
            
        @unknown default:
            throw EventKitError.accessDenied
        }
    }
    
    // MARK: - Fetching Data
    
    /// Retrieves all active calendar lists the user has enabled (iCloud, Google, Exchange).
    public func fetchActiveCalendars() -> [EKCalendar] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event)
    }
    
    /// Fetches events within a specific date range and maps them to our custom `AppEvent` model.
    /// - Parameters:
    ///   - startDate: The beginning of the timeline.
    ///   - endDate: The end of the timeline.
    ///   - calendars: Specific calendars to query. If nil, queries all active calendars.
    /// - Returns: An array of `AppEvent` ready for our SwiftUI grids.
    public func fetchEvents(from startDate: Date, to endDate: Date, in calendars: [EKCalendar]? = nil) async throws -> [AppEvent] {
        guard isAuthorized else { throw EventKitError.accessDenied }
        
        // Push the heavy predicate fetch off the MainActor to prevent UI stuttering on dense weeks
        return try await Task.detached(priority: .userInitiated) { [unowned store] in
            let targetCalendars = calendars ?? store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: targetCalendars)
            
            let ekEvents = store.events(matching: predicate)
            
            // Map the Apple objects to our hybrid BC2-style model
            return ekEvents.map { EventKitManager.mapToAppEvent($0) }
        }.value
    }
    
    // MARK: - Model Translation
    
    /// Safely extracts data from an EKEvent and packages it into our immutable AppEvent struct.
    private static func mapToAppEvent(_ ekEvent: EKEvent) -> AppEvent {
        // Convert the calendar's CGColor to a Hex String for safe Codable storage
        let hexColor = ekEvent.calendar.cgColor.toHexString() ?? "#007AFF"
        
        return AppEvent(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "Untitled Event",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            isAllDay: ekEvent.isAllDay,
            location: ekEvent.location,
            notes: ekEvent.notes,
            hasAlarms: ekEvent.hasAlarms,
            source: .eventKit,
            calendarID: ekEvent.calendar.calendarIdentifier,
            colorHex: hexColor
        )
    }
}

// MARK: - CGColor Helper
// EventKit uses CGColor. We need this to convert it to a Hex string for our DesignSystem.
extension CGColor {
    func toHexString() -> String? {
        guard let components = self.components, components.count >= 3 else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}