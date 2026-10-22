import SwiftUI
import KachiiroCore

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var confirmReset = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section {
                ForEach(Level.allCases, id: \.self) { level in
                    Toggle("\(level.rawValue) · \(level.bookName)", isOn: Binding(
                        get: { viewModel.isLevelSelected(level) },
                        set: { viewModel.setLevel(level, selected: $0) }
                    ))
                }
                Toggle("Limit lessons", isOn: Binding(
                    get: { viewModel.isLessonRangeLimited },
                    set: { viewModel.setLessonRangeLimited($0) }
                ))
                if viewModel.isLessonRangeLimited {
                    Stepper("From lesson \(viewModel.lessonStart)", value: Binding(
                        get: { viewModel.lessonStart }, set: { viewModel.setLessonStart($0) }
                    ), in: SettingsViewModel.lessonBounds)
                    Stepper("To lesson \(viewModel.lessonEnd)", value: Binding(
                        get: { viewModel.lessonEnd }, set: { viewModel.setLessonEnd($0) }
                    ), in: SettingsViewModel.lessonBounds)
                }
            } header: {
                Text("Study scope")
            } footer: {
                Text("Drills and the mock exam draw only from this scope. A change applies to the next session you start.")
            }

            Section("Practice") {
                Picker("Default input", selection: Binding(
                    get: { viewModel.inputMode }, set: { viewModel.setInputMode($0) }
                )) {
                    Text("4-Choice").tag(InputMode.choice)
                    Text("Typing").tag(InputMode.typing)
                }
                Stepper("Daily goal: \(viewModel.dailyGoal) answers", value: Binding(
                    get: { viewModel.dailyGoal }, set: { viewModel.setDailyGoal($0) }
                ), in: SettingsViewModel.goalBounds, step: SettingsViewModel.goalStep)
            }

            Section("Exam") {
                Toggle("Exam date", isOn: Binding(
                    get: { viewModel.examDate != nil },
                    set: { viewModel.setExamDate($0 ? Calendar.current.date(byAdding: .day, value: 7, to: .now) : nil) }
                ))
                if let date = viewModel.examDate {
                    DatePicker("Date", selection: Binding(
                        get: { date }, set: { viewModel.setExamDate($0) }
                    ), displayedComponents: .date)
                }
            }

            Section {
                Button("Reset progress", role: .destructive) { confirmReset = true }
            } footer: {
                Text("Deletes all answers, review state and Can-do checks on this device.")
            }
        }
        .tint(AppTheme.accent)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) { viewModel.resetProgress() }
        } message: {
            Text("This cannot be undone.")
        }
    }
}
