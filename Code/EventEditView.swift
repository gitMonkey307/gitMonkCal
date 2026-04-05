import SwiftUI
import EventKit

public struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CalendarViewModel
    
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
    @State private var selectedCalendarID: String = ""
    @State private var alarms: [TimeInterval] = []
    @State private var notes: String = ""
    @State private var recurrenceType: RecurrenceType = .none
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    public var body: some View {
        NavigationView {
            Form {
                Section("Details") {
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
                
                Section("Time") {
                    Toggle("All-day", isOn: $isAllDay)
                        .tint(.blue)
                    
                    DatePicker(
                        "Starts",
                        selection: $startDate,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    
                    DatePicker(
                        "Ends",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                }
                
                Section("Calendar") {
                    Picker("Calendar", selection: $selectedCalendarID) {
                        ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                            Text(calendar.title).tag(calendar.calendarIdentifier)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Recurrence") {
                    Picker("Repeats", selection: $recurrenceType) {
                        ForEach(RecurrenceType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Reminders") {
                    ForEach(alarms, id: \.self) { alarmOffset in
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 28, alignment: .leading)
                            Text(formatAlarmOffset(alarmOffset))
                                .font(DesignSystem.Typography.body)
                            Spacer()
                            Button(action: { removeAlarm(alarmOffset) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button(action: addDefaultAlarm) {
                        HStack {
                            Image(systemName: "bell.badge.plus")
                                .foregroundColor(.green)
                                .frame(width: 28)
                            Text("Add Reminder")
                        }
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
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
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if selectedCalendarID.isEmpty, let first = viewModel.availableCalendars.first {
                    selectedCalendarID = first.calendarIdentifier
                }
            }
        }
    }
    
    private func addDefaultAlarm() {
        let defaultOffset: TimeInterval = -900
        if !alarms.contains(defaultOffset) {
            alarms.append(defaultOffset)
            alarms.sort(by: >)
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
        Task {
            guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            do {
                try await viewModel.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    location: location.isEmpty ? nil : location,
                    notes: notes.isEmpty ? nil : notes,
                    calendarID: selectedCalendarID,
                    alarms: alarms,
                    recurrenceType: recurrenceType
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
}
