import SwiftUI
import EventKit

public struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CalendarViewModel
    
    var eventToEdit: AppEvent?
    var taskToEdit: AppReminder?
    var initialDate: Date?
    var eventToDuplicate: AppEvent?
    
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
        if eventToDuplicate != nil { return "Duplicate Event" }
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
                actionSection
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
        if eventToEdit == nil && taskToEdit == nil && eventToDuplicate == nil {
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
    private var actionSection: some View {
        if eventToEdit != nil || taskToEdit != nil {
            Section {
                if let e = eventToEdit {
                    ShareLink(item: "Event: \(title)\nDate: \(startDate.formatted())\nLocation: \(location)") {
                        Label("Share Event", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    if !e.location!.isEmpty {
                        Link(destination: URL(string: "http://maps.apple.com/?q=\(e.location!.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!) {
                            Label("Open in Maps", systemImage: "map").frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                Button("Delete", role: .destructive) {
                    if eventToEdit != nil { viewModel.deleteEvent(eventToEdit!) }
                    if taskToEdit != nil { viewModel.deleteTask(taskToEdit!) }
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private func setupInitialState() {
        if let e = eventToEdit {
            isTask = false; title = e.title; location = e.location ?? ""; isAllDay = e.isAllDay
            startDate = e.startDate; endDate = e.endDate; notes = e.notes ?? ""; selectedID = e.calendarID
            alarms = e.alarms; recurrenceType = e.recurrence
        } else if let dup = eventToDuplicate {
            isTask = false; title = dup.title + " (Copy)"; location = dup.location ?? ""; isAllDay = dup.isAllDay
            startDate = dup.startDate; endDate = dup.endDate; notes = dup.notes ?? ""; selectedID = dup.calendarID
            alarms = dup.alarms; recurrenceType = dup.recurrence
        } else if let t = taskToEdit {
            isTask = true; title = t.title; startDate = t.dueDate ?? Date(); notes = t.notes ?? ""; selectedID = t.listID
        } else {
            if isTask {
                selectedID = viewModel.availableReminderLists.first?.calendarIdentifier ?? ""
            } else {
                selectedID = viewModel.availableCalendars.first?.calendarIdentifier ?? ""
            }
            if let target = initialDate {
                if let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: target) {
                    startDate = noon; endDate = Calendar.current.date(byAdding: .minute, value: viewModel.defaultDuration, to: noon) ?? noon
                } else { startDate = target; endDate = target }
            } else {
                endDate = Calendar.current.date(byAdding: .minute, value: viewModel.defaultDuration, to: startDate) ?? startDate
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
            await viewModel.refreshData(); dismiss()
        } catch { print("Save failed: \(error)") }
        isSaving = false
    }
}
