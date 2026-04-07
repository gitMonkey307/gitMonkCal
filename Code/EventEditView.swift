import SwiftUI
import EventKit

public struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CalendarViewModel
    
    @State private var isTask: Bool = false
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
    @State private var selectedID: String = ""
    @State private var notes: String = ""
    @State private var alarms: [TimeInterval] = []
    @State private var isSaving = false

    public var body: some View {
        NavigationView {
            Form {
                Picker("Type", selection: $isTask) {
                    Text("Event").tag(false)
                    Text("Task").tag(true)
                }
                .pickerStyle(.segmented).padding(.vertical, 4)
                
                Section("Details") {
                    TextField(isTask ? "Task Title" : "Event Title", text: $title)
                        .font(DesignSystem.Typography.header)
                    if !isTask { TextField("Location", text: $location) }
                }
                
                Section("Time") {
                    if !isTask { Toggle("All-day", isOn: $isAllDay) }
                    DatePicker(isTask ? "Due Date" : "Starts", selection: $startDate)
                    if !isTask { DatePicker("Ends", selection: $endDate, in: startDate...) }
                }
                
                Section(isTask ? "List" : "Calendar") {
                    Picker("Select", selection: $selectedID) {
                        if isTask {
                            ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                        } else {
                            ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                        }
                    }
                }
                Section("Notes") { TextEditor(text: $notes).frame(minHeight: 100) }
            }
            .navigationTitle(isTask ? "New Task" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") { Task { await save() } }
                        .fontWeight(.bold).disabled(title.isEmpty || isSaving)
                }
            }
            .onAppear {
                selectedID = isTask ? (viewModel.availableReminderLists.first?.calendarIdentifier ?? "") : (viewModel.availableCalendars.first?.calendarIdentifier ?? "")
            }
        }
    }
    
    private func save() async {
        isSaving = true
        do {
            if isTask {
                try await viewModel.eventKitManager.saveTask(title: title, dueDate: startDate, notes: notes, listID: selectedID)
            } else {
                try await viewModel.eventKitManager.saveEvent(title: title, start: startDate, end: endDate, isAllDay: isAllDay, location: location, notes: notes, calendarID: selectedID, alarms: alarms)
            }
            await viewModel.refreshData()
            dismiss()
        } catch { print("Save failed: \(error)") }
        isSaving = false
    }
}
