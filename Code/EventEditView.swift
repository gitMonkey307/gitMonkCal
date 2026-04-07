import SwiftUI
import EventKit

public struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CalendarViewModel
    var eventToEdit: AppEvent?; var taskToEdit: AppReminder?; var initialDate: Date?; var eventToDuplicate: AppEvent?
    
    @State private var isTask: Bool = false
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
    @State private var selectedID: String = ""
    @State private var notes: String = ""
    @State private var recurrenceType: RecurrenceType = .none
    @State private var customColor: Color = .blue
    @State private var alarms: [TimeInterval] = []
    @State private var isSaving = false

    private var navTitle: String {
        if eventToDuplicate != nil { return "Duplicate Event" }
        if eventToEdit != nil { return "Edit Event" }
        if taskToEdit != nil { return "Edit Task" }
        return isTask ? "New Task" : "New Event"
    }
    
    private var isSaveDisabled: Bool { title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving }

    public var body: some View {
        NavigationView {
            Form {
                templateSection
                typeSection
                // FIXED: Wrapped in Group to satisfy Section inference
                Section(header: Text("Details")) {
                    Group {
                        TextField("Title", text: $title).font(DesignSystem.Typography.header)
                        TextField("Location", text: $location)
                        recentLocationsPicker
                    }
                }
                colorSection
                timeSection
                if !isTask { recurrenceSection }
                calendarListSection
                notesSection
                actionSection
            }
            .navigationTitle(navTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaveDisabled)
                }
            }
            .onAppear(perform: setupInitialState)
        }
    }
    
    @ViewBuilder
    private var recentLocationsPicker: some View {
        if !viewModel.recentLocations.isEmpty && location.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.recentLocations, id: \.self) { loc in
                        Button(loc) { location = loc }.font(.caption).padding(6).background(Color.secondary.opacity(0.1)).cornerRadius(6)
                    }
                }
            }
        }
    }

    @ViewBuilder private var actionSection: some View {
        Section {
            Group {
                if !location.isEmpty {
                    Button { 
                        let url = URL(string: "http://maps.apple.com/?q=\(location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
                        UIApplication.shared.open(url)
                    } label: { Label("Open in Maps", systemImage: "map") }
                }
                if eventToEdit != nil || taskToEdit != nil {
                    Button("Delete", role: .destructive) {
                        if let e = eventToEdit { viewModel.deleteEvent(e) }
                        if let t = taskToEdit { viewModel.deleteTask(t) }
                        dismiss()
                    }
                }
            }
        }
    }

    private func setupInitialState() {
        if let e = eventToEdit {
            isTask = false; title = e.title; location = e.location ?? ""; isAllDay = e.isAllDay; startDate = e.startDate; endDate = e.endDate; notes = e.notes ?? ""; selectedID = e.calendarID; alarms = e.alarms; recurrenceType = e.recurrence
        } else if let t = taskToEdit {
            isTask = true; title = t.title; startDate = t.dueDate ?? Date(); notes = t.notes ?? ""; selectedID = t.listID
        } else {
            selectedID = isTask ? (viewModel.availableReminderLists.first?.calendarIdentifier ?? "") : (viewModel.availableCalendars.first?.calendarIdentifier ?? "")
        }
    }
    
    private func save() async {
        isSaving = true
        viewModel.saveLocation(location) // FIXED: saveLocation is now back in VM scope
        if isTask {
            try? await viewModel.eventKitManager.saveTask(id: taskToEdit?.id, title: title, dueDate: startDate, notes: notes, listID: selectedID)
        } else {
            try? await viewModel.eventKitManager.saveEvent(id: eventToEdit?.id, title: title, start: startDate, end: endDate, isAllDay: isAllDay, location: location, notes: notes, calendarID: selectedID, alarms: alarms, recurrenceType: recurrenceType)
        }
        await viewModel.refreshData(); dismiss()
    }
    
    @ViewBuilder private var templateSection: some View { if !viewModel.templates.isEmpty && eventToEdit == nil { Section("Templates") { ScrollView(.horizontal) { HStack { ForEach(viewModel.templates) { t in Button(t.title) { title = t.title; location = t.location ?? "" }.padding(8).background(Color.secondary.opacity(0.1)).cornerRadius(8) } } } } } }
    @ViewBuilder private var typeSection: some View { if eventToEdit == nil && taskToEdit == nil && eventToDuplicate == nil { Picker("Type", selection: $isTask) { Text("Event").tag(false); Text("Task").tag(true) }.pickerStyle(.segmented).padding(.vertical, 4) } }
    @ViewBuilder private var colorSection: some View { if !isTask { Section("Color") { ColorPicker("Custom Highlight", selection: $customColor) } } }
    @ViewBuilder private var timeSection: some View { Section("Time") { if !isTask { Toggle("All-day", isOn: $isAllDay) }; DatePicker(isTask ? "Due Date" : "Starts", selection: $startDate); if !isTask { DatePicker("Ends", selection: $endDate, in: startDate...) } } }
    @ViewBuilder private var recurrenceSection: some View { Section("Repeat") { Picker("Interval", selection: $recurrenceType) { ForEach(RecurrenceType.allCases) { Text($0.displayName).tag($0) } } } }
    @ViewBuilder private var calendarListSection: some View { Section(isTask ? "List" : "Calendar") { Picker("Select", selection: $selectedID) { if isTask { ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) } } else { ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) } } } } }
    @ViewBuilder private var notesSection: some View { Section("Notes") { TextEditor(text: $notes).frame(minHeight: 100) } }
}
