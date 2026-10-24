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
                Toggle("Exam date", isOn: Binding(
                    get: { viewModel.examDate != nil },
                    set: { viewModel.setExamDate($0 ? Calendar.current.date(byAdding: .day, value: 7, to: .now) : nil) }
                ))
                if let date = viewModel.examDate {
                    DatePicker("Date", selection: Binding(
                        get: { date }, set: { viewModel.setExamDate($0) }
                    ), displayedComponents: .date)
                }
                Stepper(value: Binding(
                    get: { viewModel.dailyGoal }, set: { viewModel.setDailyGoal($0) }
                ), in: SettingsViewModel.goalBounds, step: SettingsViewModel.goalStep) {
                    LabeledContent("Daily goal", value: "\(viewModel.dailyGoal) answers")
                }
            } header: {
                sectionHeader("My goal", icon: "flag.checkered")
            } footer: {
                Text("Today builds its plan and the exam track from these.")
            }

            Section {
                ForEach(Level.allCases, id: \.self) { level in
                    Toggle("\(level.bookName) · \(level.rawValue)", isOn: Binding(
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
                sectionHeader("What I study", icon: "books.vertical")
            } footer: {
                Text("Drills and the mock exam draw only from this scope. A change applies to the next session you start.")
            }

            Section {
                Picker("Answer with", selection: Binding(
                    get: { viewModel.inputMode }, set: { viewModel.setInputMode($0) }
                )) {
                    Text("4 choices").tag(InputMode.choice)
                    Text("Typing").tag(InputMode.typing)
                }
            } header: {
                sectionHeader("How I practise", icon: "hand.tap")
            } footer: {
                Text("You can still switch per question with “Type instead”.")
            }

            kaiwaSection

            Section {
                Button("Reset all progress…", role: .destructive) { confirmReset = true }
            } footer: {
                Text("Deletes all answers, review state and Can-do checks on this device.")
            }
        }
        .tint(AppTheme.accent)
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas)
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

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTheme.Fonts.ui(.footnote, weight: .heavy))
            .foregroundStyle(AppTheme.secondaryInk)
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
            sectionHeader("AI partner", icon: "sparkles")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(engineFooter)
                if viewModel.kaiwaEngine == .gemini {
                    Text("The key is stored in the Keychain on this device. Live voice roleplay needs Content set to AI-generated.")
                }
            }
        }
    }
}
