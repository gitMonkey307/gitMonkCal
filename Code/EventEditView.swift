import SwiftUI
import EventKit
import Foundation

public struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CalendarViewModel
    var eventToEdit: AppEvent?; var taskToEdit: AppReminder?; var initialDate: Date?; var eventToDuplicate: AppEvent?
    
    @State private var isTask: Bool = false
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Foundation.Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
    @State private var selectedID: String = ""
    @State private var notes: String = ""
    @State private var recurrenceType: RecurrenceType = .none
    @State private var customColor: Color = .blue
    @State private var taskPriority: Int = 0
    @State private var alarms: [TimeInterval] = []
    @State private var isSaving = false

    public var body: some View {
        NavigationView {
            Form {
                templateSection
                typeSection
                Section(header: Text("Details")) {
                    Group {
                        TextField("Title", text: $title).font(DesignSystem.Typography.header)
                        TextField("Location", text: $location)
                        recentLocationsPicker
                    }
                }
                if isTask {
                    Section("Priority") { Picker("Level", selection: $taskPriority) { Text("None").tag(0); Text("High").tag(1); Text("Med").tag(5); Text("Low").tag(9) }.pickerStyle(.segmented) }
                } else {
                    Section("Color") { ColorPicker("Highlight Event", selection: $customColor) }
                }
                timeSection
                if !isTask { recurrenceSection; alarmSection }
                calendarListSection
                notesSection
                actionSection
            }
            .navigationTitle(eventToEdit != nil ? "Edit" : "New Entry")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(title.isEmpty || isSaving)
                }
            }
            .onAppear(perform: setupInitialState)
        }
    }

    private func save() async {
        isSaving = true
        viewModel.saveLocation(location)
        let colorHex = customColor.toHex()
        
        do {
            if isTask {
                try await viewModel.eventKitManager.saveTask(id: taskToEdit?.id, title: title, dueDate: startDate, notes: notes, listID: selectedID, priority: taskPriority)
            } else {
                try await viewModel.eventKitManager.saveEvent(id: eventToEdit?.id, title: title, start: startDate, end: endDate, isAllDay: isAllDay, location: location, notes: notes, calendarID: selectedID, alarms: alarms, recurrenceType: recurrenceType, customColorHex: colorHex)
            }
            await viewModel.refreshData(); dismiss()
        } catch { print("Save fail") }
        isSaving = false
    }
    
    private func setupInitialState() {
        if let e = eventToEdit {
            isTask = false; title = e.title; location = e.location ?? ""; isAllDay = e.isAllDay; startDate = e.startDate; endDate = e.endDate; notes = e.notes ?? ""; selectedID = e.calendarID; alarms = e.alarms; recurrenceType = e.recurrence
            if let hex = e.customColorHex, let c = Color(hex) { customColor = c }
        } else if let t = taskToEdit {
            isTask = true; title = t.title; startDate = t.dueDate ?? Date(); notes = t.notes ?? ""; selectedID = t.listID; taskPriority = t.priority
        } else {
            selectedID = isTask ? (viewModel.availableReminderLists.first?.calendarIdentifier ?? "") : (viewModel.availableCalendars.first?.calendarIdentifier ?? "")
            if let target = initialDate {
                if let noon = Foundation.Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: target) {
                    startDate = noon; endDate = Foundation.Calendar.current.date(byAdding: .minute, value: viewModel.defaultDuration, to: noon) ?? noon
                }
            }
        }
    }

    @ViewBuilder private var templateSection: some View { if !viewModel.templates.isEmpty && eventToEdit == nil { Section("Templates") { ScrollView(.horizontal) { HStack { ForEach(viewModel.templates) { t in Button(t.title) { title = t.title; location = t.location ?? "" }.padding(8).background(Color.secondary.opacity(0.1)).cornerRadius(8) } } } } } }
    @ViewBuilder private var typeSection: some View { if eventToEdit == nil && taskToEdit == nil && eventToDuplicate == nil { Picker("Type", selection: $isTask) { Text("Event").tag(false); Text("Task").tag(true) }.pickerStyle(.segmented).padding(.vertical, 4) } }
    @ViewBuilder private var timeSection: some View { Section("Time") { if !isTask { Toggle("All-day", isOn: $isAllDay) }; DatePicker(isTask ? "Due Date" : "Starts", selection: $startDate); if !isTask { DatePicker("Ends", selection: $endDate, in: startDate...) } } }
    @ViewBuilder private var recurrenceSection: some View { Section("Repeat") { Picker("Interval", selection: $recurrenceType) { ForEach(RecurrenceType.allCases) { Text($0.displayName).tag($0) } } } }
    @ViewBuilder private var alarmSection: some View { Section("Alarms") { Button("Add Alarm") { alarms.append(-900) }; ForEach(0..<alarms.count, id: \.self) { i in HStack { Text("\(Int(abs(alarms[i])/60))m before"); Spacer(); Button(role: .destructive) { alarms.remove(at: i) } label: { Image(systemName: "minus.circle") } } } } }
    @ViewBuilder private var calendarListSection: some View { Section(isTask ? "List" : "Calendar") { Picker("Select", selection: $selectedID) { if isTask { ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) } } else { ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) } } } } }
    @ViewBuilder private var notesSection: some View { Section("Notes") { TextEditor(text: $notes).frame(minHeight: 100) } }
    @ViewBuilder private var recentLocationsPicker: some View { if !viewModel.recentLocations.isEmpty && location.isEmpty { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(viewModel.recentLocations, id: \.self) { loc in Button(loc) { location = loc }.font(.caption).padding(6).background(Color.secondary.opacity(0.1)).cornerRadius(6) } } } } }
    @ViewBuilder private var actionSection: some View { Section { Group { if let e = eventToEdit { ShareLink(item: "Event: \(title)\nAt: \(location)\nDate: \(startDate.formatted())") { Label("Share Event", systemImage: "square.and.arrow.up") }; if !location.isEmpty, let enc = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: "http://maps.apple.com/?q=\(enc)") { Button { UIApplication.shared.open(url) } label: { Label("Open in Maps", systemImage: "map") } } }; if eventToEdit != nil || taskToEdit != nil { Button("Delete Entry", role: .destructive) { if let e = eventToEdit { viewModel.deleteEvent(e) } else if let t = taskToEdit { viewModel.deleteTask(t) }; dismiss() }.frame(maxWidth: .infinity, alignment: .center) } } } }
}
