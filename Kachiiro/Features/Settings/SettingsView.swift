import SwiftUI
import KachiiroCore

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var confirmReset = false
    @State private var geminiKeyDraft = ""
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

            kaiwaSection
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

    private var engineFooter: String {
        switch viewModel.availability(of: viewModel.kaiwaEngine) {
        case .available: viewModel.kaiwaEngine == .rules ? "Rule-based keigo checks and bundled content. Works offline." : "Ready"
        case .unavailable(let reason): "Unavailable: \(reason). Offline rules are used instead."
        }
    }

    private var kaiwaSection: some View {
        Section {
            Picker("Engine", selection: Binding(
                get: { viewModel.kaiwaEngine }, set: { viewModel.setKaiwaEngine($0) }
            )) {
                ForEach(KaiwaEngine.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            if viewModel.kaiwaEngine == .gemini {
                if viewModel.hasGeminiKey {
                    Label("API key saved", systemImage: "key.fill")
                    Button("Remove key", role: .destructive) { viewModel.removeGeminiKey() }
                } else {
                    SecureField("Gemini API key", text: $geminiKeyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save key") {
                        if viewModel.saveGeminiKey(geminiKeyDraft) { geminiKeyDraft = "" }
                    }
                    .disabled(geminiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Picker("Content", selection: Binding(
                get: { viewModel.kaiwaContent }, set: { viewModel.setKaiwaContent($0) }
            )) {
                ForEach(KaiwaContentSource.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .disabled(!viewModel.isContentPickerEnabled)
        } header: {
            Text("Kaiwa (speaking)")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(engineFooter)
                if viewModel.kaiwaEngine == .gemini { Text("Stored in the Keychain on this device.") }
            }
        }
    }
}
