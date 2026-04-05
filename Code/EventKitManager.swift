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
@MainActor
public class EventKitManager: ObservableObject {
    
    private let store = EKEventStore()
    @Published public var isAuthorized: Bool = false
    
    public init() {
        checkInitialAuthorizationStatus()
    }
    
    private func checkInitialAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        // FIXED: Removed deprecated .authorized for iOS 17+ strict compliance
        self.isAuthorized = (status == .fullAccess)
    }
    
    public func requestCalendarAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .notDetermined:
            let granted = try await store.requestFullAccessToEvents()
            self.isAuthorized = granted
            if !granted { throw EventKitError.accessDenied }
            
        case .restricted:
            throw EventKitError.restricted
            
        case .denied:
            throw EventKitError.accessDenied
            
        case .fullAccess:
            self.isAuthorized = true
            
        // FIXED: Added the missing iOS 17 case to satisfy the compiler
        case .writeOnly:
            throw EventKitError.accessDenied // We need full read/write for a calendar app
            
        // Retained for backward compatibility fallback just in case
        case .authorized: 
            self.isAuthorized = true
            
        @unknown default:
            throw EventKitError.accessDenied
        }
    }
    
    public func fetchActiveCalendars() -> [EKCalendar] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event)
    }
    
    public func fetchEvents(from startDate: Date, to endDate: Date, in calendars: [EKCalendar]? = nil) async throws -> [AppEvent] {
        guard isAuthorized else { throw EventKitError.accessDenied }
        
        // FIXED: Removed unnecessary 'try' to silence the warning
        return await Task.detached(priority: .userInitiated) { [unowned store] in
            let targetCalendars = calendars ?? store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: targetCalendars)
            
            let ekEvents = store.events(matching: predicate)
            
            return ekEvents.map { EventKitManager.mapToAppEvent($0) }
        }.value
    }
    
    // FIXED: Added 'nonisolated' so the background thread can safely access this function
    nonisolated private static func mapToAppEvent(_ ekEvent: EKEvent) -> AppEvent {
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
