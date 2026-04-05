import SwiftUI
import EventKit

struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CalendarViewModel
    let selectedDate: Date
    let isTask: Bool
    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var isAllDay = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var selectedCalendarID = ""
    @State private var alarms: [TimeInterval] = []
    @State private var recurrence: RecurrenceRule?
    @State private var priority: Int = 3
    @State private var cancelled = false
    @State private var showingError = false
    @State private var errorMsg = ""
    // Templates
    @AppStorage("templates") private var templatesData: Data = Data()
    @State private var templates: [EventTemplate] = []
    @State private var selectedTemplate = ""

    struct EventTemplate: Codable {
        let name: String
        let event: AppEvent
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Location", text: $location)
                }

                Section("Time") {
                    Toggle("All Day", isOn: $isAllDay)
                    DatePicker("Start", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                }

                Section("Calendar") {
                    Picker("Calendar", selection: $selectedCalendarID) {
                        ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { cal in
                            Text(cal.title).tag(cal.calendarIdentifier)
                        }
                    }
                }

                if !isTask {
                    Section("Recurrence") {
                        Picker("Repeat", selection: Binding<RecurrenceRule?>(get: { recurrence }, set: { recurrence = $0 })) {
                            Text("None").tag(nil as RecurrenceRule?)
                            ForEach(RecurrenceRule.Frequency.allCases.prefix(4), id: \.self) { freq in
                                Text("Every \(freq.rawValue.capitalized)").tag(RecurrenceRule(frequency: freq, interval: 1) as RecurrenceRule?)
                            }
                        }
                    }
                } else {
                    Section("Priority") {
                        Picker("Priority", selection: $priority) {
                            ForEach(1...5, id: \.self) { p in Text("\(p) Stars").tag(p) }
                        }
                    }
                }

                Section("Reminders") {
                    ForEach(alarms, id: \.self) { offset in
                        Text(formatAlarm(offset))
                        Button("Delete") { alarms.removeAll { $0 == offset } }
                    }
                    Button("Add 15 min") { addAlarm(-900) }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                }

                Section("Templates") {
                    Picker("Template", selection: $selectedTemplate) {
                        Text("None").tag("")
                        ForEach(templates.indices, id: \.self) { i in
                            Text(templates[i].name).tag(templates[i].name)
                        }
                    }
                    Button("Save as Template") { saveTemplate() }
                }
            }
            .navigationTitle(isTask ? "New Task" : "New Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear {
                startDate = selectedDate
                if let firstCal = viewModel.availableCalendars.first { selectedCalendarID = firstCal.calendarIdentifier }
                loadTemplates()
            }
            .alert("Error", isPresented: $showingError) { } message: { Text(errorMsg) }
            .onChange(of: selectedTemplate) { applyTemplate($1) }
        }
    }

    private func save() {
        Task {
            do {
                try await viewModel.createEvent(
                    title: title, startDate: startDate, endDate: endDate, isAllDay: isAllDay,
                    location: location.isEmpty ? nil : location, notes: notes.isEmpty ? nil : notes,
                    calendarID: selectedCalendarID, alarms: alarms, recurrence: recurrence, priority: isTask ? priority : nil, isTask: isTask
                )
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
                showingError = true
            }
        }
    }

    private func addAlarm(_ offset: TimeInterval) {
        if !alarms.contains(offset) { alarms.append(offset); alarms.sort(by: >) }
    }

    private func formatAlarm(_ offset: TimeInterval) -> String {
        let abs = abs(offset / 60)
        if abs < 60 { return "\(Int(abs)) min before" }
        return "\(Int(abs / 60)) hrs before"
    }

    private func loadTemplates() {
        if let decoded = try? JSONDecoder().decode([EventTemplate].self, from: templatesData) {
            templates = decoded
        }
    }

    private func saveTemplate() {
        let template = EventTemplate(name: title.prefix(20).description, event: AppEvent(title: title, /* fill from states */ startDate: startDate, endDate: endDate, calendarID: selectedCalendarID))
        templates.append(template)
        if let encoded = try? JSONEncoder().encode(templates) { templatesData = encoded }
    }

    private func applyTemplate(_ name: String) {
        if let template = templates.first(where: { $0.name == name }) {
            title = template.event.title
            // Apply other fields...
        }
    }
}
