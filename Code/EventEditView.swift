import SwiftUI
import EventKit

public struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CalendarViewModel
    
    // MARK: - Form State
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600) // Default 1 hr
    
    // Default to the first available calendar if one exists
    @State private var selectedCalendarID: String = "" 
    @State private var alarms: [TimeInterval] = []
    @State private var notes: String = ""
    
    public var body: some View {
        NavigationView {
            Form {
                // 1. Title & Core Details (BC2 Top Block)
                Section {
                    HStack(alignment: .center) {
                        Image(systemName: "text.cursor")
                            .foregroundColor(.blue)
                            .frame(width: 28, alignment: .leading)
                        
                        TextField("Event Title", text: $title)
                            .font(DesignSystem.Typography.header)
                    }
                    
                    HStack(alignment: .center) {
                        Image(systemName: DesignSystem.Icons.location)
                            .foregroundColor(.red)
                            .frame(width: 28, alignment: .leading)
                        
                        TextField("Location", text: $location)
                            .font(DesignSystem.Typography.body)
                    }
                }
                
                // 2. Time Blocks
                Section {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                            .frame(width: 28, alignment: .leading)
                        
                        Toggle("All-day", isOn: $isAllDay)
                            .tint(.blue) // iOS native standard
                    }
                    
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .leading)
                        
                        // Inline iOS Pickers replacing Android popup dialogs
                        DatePicker(
                            "Starts",
                            selection: $startDate,
                            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                        )
                    }
                    
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .leading)
                        
                        DatePicker(
                            "Ends",
                            selection: $endDate,
                            in: startDate..., // Enforce logical end times natively
                            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                        )
                    }
                }
                
                // 3. Calendar Selection
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.purple)
                            .frame(width: 28, alignment: .leading)
                        
                        Picker("Calendar", selection: $selectedCalendarID) {
                            ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                                Text(calendar.title).tag(calendar.calendarIdentifier)
                            }
                        }
                        .pickerStyle(.menu) // Keeps it inline and clean
                    }
                }
                
                // 4. Custom Notifications (Replicating BC2's multi-alert capability)
                Section {
                    ForEach(alarms, id: \.self) { alarmOffset in
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 28, alignment: .leading)
                            
                            Text(formatAlarmOffset(alarmOffset))
                                .font(DesignSystem.Typography.body)
                            
                            Spacer()
                            
                            // Native inline deletion
                            Button(action: { removeAlarm(alarmOffset) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Button(action: addDefaultAlarm) {
                        HStack {
                            Image(systemName: "bell.badge.plus")
                                .foregroundColor(.green)
                                .frame(width: 28, alignment: .leading)
                            
                            Text("Add Custom Reminder")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // 5. Description / Notes
                Section {
                    HStack(alignment: .top) {
                        Image(systemName: "note.text")
                            .foregroundColor(.gray)
                            .frame(width: 28, alignment: .leading)
                            .padding(.top, 8)
                        
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEvent() }
                        .fontWeight(.bold)
                        // Disable save if there's no title
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                // Ensure a default calendar is selected upon opening
                if selectedCalendarID.isEmpty, let first = viewModel.availableCalendars.first {
                    selectedCalendarID = first.calendarIdentifier
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    private func addDefaultAlarm() {
        // Adds a standard 15-minute before alert (-900 seconds)
        let defaultOffset: TimeInterval = -900 
        if !alarms.contains(defaultOffset) {
            alarms.append(defaultOffset)
            alarms.sort(by: >) // Keep alarms ordered chronologically
        }
    }
    
    private func removeAlarm(_ offset: TimeInterval) {
        alarms.removeAll { $0 == offset }
    }
    
    private func formatAlarmOffset(_ offset: TimeInterval) -> String {
        if offset == 0 { return "At time of event" }
        let minutes = abs(Int(offset) / 60)
        if minutes < 60 {
            return "\(minutes) minutes before"
        } else {
            let hours = minutes / 60
            return "\(hours) hour\(hours > 1 ? "s" : "") before"
        }
    }
    
    private func saveEvent() {
        // Integration point: Map these variables to an EKEvent via EventKitManager
        // and save it to the database. For now, we dismiss the sheet.
        dismiss()
    }
}