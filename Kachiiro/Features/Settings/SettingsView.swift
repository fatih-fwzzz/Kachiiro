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
        if let notice = viewModel.engineNotice { return notice }
        let checks = "Keigo questions and answer checks always use Gemini, the more accurate engine."
        switch viewModel.activeEngine {
        case .appleIntelligence: return "Shadowing phrases and free conversation run on this device. " + checks
        case .gemini: return "Runs online with Google’s Gemini. Live voice roleplay needs Content set to AI-generated."
        case .rules, .automatic: return "AI isn’t available right now; offline checks and bundled content are used."
        }
    }

    private var kaiwaSection: some View {
        Section {
            if viewModel.engineChoices.count > 1 {
                Picker("Conversation engine", selection: Binding(
                    get: { viewModel.activeEngine }, set: { viewModel.setKaiwaEngine($0) }
                )) {
                    ForEach(viewModel.engineChoices, id: \.self) { Text($0.label).tag($0) }
                }
            } else {
                LabeledContent("Engine", value: viewModel.activeEngine == .rules ? "Offline" : viewModel.activeEngine.label)
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
            Text(engineFooter)
        }
    }
}
