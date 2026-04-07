import SwiftUI
import EventKit

public struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CalendarViewModel
    
    var eventToEdit: AppEvent?
    var taskToEdit: AppReminder?
    var initialDate: Date? // NEW: Supports Contextual creation
    
    @State private var isTask: Bool = false
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
    @State private var selectedID: String = ""
    @State private var notes: String = ""
    @State private var recurrenceType: RecurrenceType = .none
    @State private var alarms: [TimeInterval] = []
    @State private var isSaving = false

    private var navTitle: String {
        if eventToEdit != nil { return "Edit Event" }
        if taskToEdit != nil { return "Edit Task" }
        return isTask ? "New Task" : "New Event"
    }
    
    private var isSaveDisabled: Bool {
        return title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving
    }

    public var body: some View {
        NavigationView {
            Form {
                typeSection
                detailsSection
                timeSection
                if !isTask { recurrenceSection }
                calendarListSection
                notesSection
                deleteSection
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") { Task { await save() } }
                        .fontWeight(.bold)
                        .disabled(isSaveDisabled)
                }
            }
            .onAppear(perform: setupInitialState)
        }
    }
    
    @ViewBuilder
    private var typeSection: some View {
        if eventToEdit == nil && taskToEdit == nil {
            Picker("Type", selection: $isTask) {
                Text("Event").tag(false)
                Text("Task").tag(true)
            }
            .pickerStyle(.segmented).padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField(isTask ? "Task Title" : "Event Title", text: $title).font(DesignSystem.Typography.header)
            if !isTask { TextField("Location", text: $location) }
        }
    }
    
    @ViewBuilder
    private var timeSection: some View {
        Section("Time") {
            if !isTask { Toggle("All-day", isOn: $isAllDay) }
            DatePicker(isTask ? "Due Date" : "Starts", selection: $startDate)
            if !isTask { DatePicker("Ends", selection: $endDate, in: startDate...) }
        }
    }
    
    @ViewBuilder
    private var recurrenceSection: some View {
        Section("Recurrence & Alarms") {
            Picker("Repeat", selection: $recurrenceType) {
                ForEach(RecurrenceType.allCases) { Text($0.displayName).tag($0) }
            }
            Button("Add Alarm (15m before)") { alarms.append(-900) }
            ForEach(alarms, id: \.self) { offset in
                Text("\(Int(abs(offset)/60)) minutes before").foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var calendarListSection: some View {
        Section(isTask ? "List" : "Calendar") {
            Picker("Select", selection: $selectedID) {
                if isTask {
                    ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                } else {
                    ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                }
            }
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        Section("Notes") { TextEditor(text: $notes).frame(minHeight: 100) }
    }
    
    @ViewBuilder
    private var deleteSection: some View {
        if eventToEdit != nil || taskToEdit != nil {
            Section {
                Button("Delete", role: .destructive) {
                    if let e = eventToEdit { viewModel.deleteEvent(e) }
                    if let t = taskToEdit { viewModel.deleteTask(t) }
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private func setupInitialState() {
        if let e = eventToEdit {
            isTask = false
            title = e.title
            location = e.location ?? ""
            isAllDay = e.isAllDay
            startDate = e.startDate
            endDate = e.endDate
            notes = e.notes ?? ""
            selectedID = e.calendarID
            alarms = e.alarms
            recurrenceType = e.recurrence
        } else if let t = taskToEdit {
            isTask = true
            title = t.title
            startDate = t.dueDate ?? Date()
            notes = t.notes ?? ""
            selectedID = t.listID
        } else {
            // Setup default lists
            if isTask {
                selectedID = viewModel.availableReminderLists.first?.calendarIdentifier ?? ""
            } else {
                selectedID = viewModel.availableCalendars.first?.calendarIdentifier ?? ""
            }
            // Apply contextual Date routing if provided
            if let target = initialDate {
                // Set default time to Noon for tapped days
                if let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: target) {
                    startDate = noon
                    endDate = Calendar.current.date(byAdding: .hour, value: 1, to: noon) ?? noon
                } else {
                    startDate = target
                    endDate = target
                }
            }
        }
    }
    
    private func save() async {
        isSaving = true
        do {
            if isTask {
                try await viewModel.eventKitManager.saveTask(id: taskToEdit?.id, title: title, dueDate: startDate, notes: notes, listID: selectedID)
            } else {
                try await viewModel.eventKitManager.saveEvent(id: eventToEdit?.id, title: title, start: startDate, end: endDate, isAllDay: isAllDay, location: location, notes: notes, calendarID: selectedID, alarms: alarms, recurrenceType: recurrenceType)
            }
            await viewModel.refreshData()
            dismiss()
        } catch { print("Save failed: \(error)") }
        isSaving = false
    }
}
