import SwiftUI
import KachiiroCore

/// First run: three answers and Today has a plan to the exam.
struct SetupView: View {
    @State private var model: SetupViewModel
    @Environment(\.dismiss) private var dismiss

    init(model: SetupViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("勝")
                    .font(.system(size: 34, weight: .black, design: .serif))
                    .frame(width: 60, height: 60)
                    .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 2))
                    .padding(6)
                    .background(AppTheme.accent, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Let’s plan your win.")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    Text("Three answers and Kachiiro builds a day-by-day plan to your exam.")
                        .font(AppTheme.Fonts.ui(.callout))
                        .foregroundStyle(AppTheme.onKachiiroSecondary)
                }
                examSection
                goalSection
                bookSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .background(AppTheme.kachiiro.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button("Build my plan") {
                    model.finish()
                    dismiss()
                }
                .buttonStyle(.primary)
                Button("Skip for now") {
                    model.skip()
                    dismiss()
                }
                .buttonStyle(.quiet)
                .foregroundStyle(AppTheme.onKachiiroLabel)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(AppTheme.kachiiro.ignoresSafeArea())
        }
    }

    private var examSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaps(text: "1 · When is your exam?", color: AppTheme.onKachiiroLabel)
            if model.hasExamDate {
                DatePicker("Exam date", selection: $model.examDate, in: Date.now..., displayedComponents: .date)
                    .font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(optionFill(selected: true), in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
                    .overlay(optionStroke(selected: true))
            }
            Toggle("I don’t have a date yet", isOn: Binding(get: { !model.hasExamDate }, set: { model.hasExamDate = !$0 }))
                .font(AppTheme.Fonts.ui(.subheadline, weight: .semibold))
                .tint(AppTheme.accent)
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaps(text: "2 · How much each day?", color: AppTheme.onKachiiroLabel)
            HStack(spacing: 8) {
                ForEach(SetupViewModel.goalChoices, id: \.self) { goal in
                    let selected = model.dailyGoal == goal
                    Button { model.dailyGoal = goal } label: {
                        VStack(spacing: 2) {
                            Text("\(goal)").font(AppTheme.Fonts.ui(.title2, weight: .heavy))
                            Text("answers · ≈ \(SetupViewModel.minutes(forGoal: goal)) min")
                                .font(AppTheme.Fonts.ui(.caption, weight: .semibold))
                                .foregroundStyle(AppTheme.onKachiiroSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 74)
                        .background(optionFill(selected: selected), in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
                        .overlay(optionStroke(selected: selected))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var bookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaps(text: "3 · Which book are you on?", color: AppTheme.onKachiiroLabel)
            HStack(spacing: 8) {
                ForEach(Level.allCases, id: \.self) { level in
                    let selected = model.level == level
                    Button { model.level = level } label: {
                        VStack(spacing: 2) {
                            Text(level.bookName).font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                            Text(level.rawValue).font(AppTheme.Fonts.ui(.caption, weight: .semibold))
                                .foregroundStyle(AppTheme.onKachiiroSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(optionFill(selected: selected), in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
                        .overlay(optionStroke(selected: selected))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Text("You can widen this or limit lessons later in Settings.")
                .font(AppTheme.Fonts.ui(.footnote))
                .foregroundStyle(AppTheme.onKachiiroSecondary)
        }
    }

    private func optionFill(selected: Bool) -> Color {
        selected ? Color(hex: 0x0A84FF).opacity(0.16) : .clear
    }

    private func optionStroke(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
            .strokeBorder(selected ? Color(hex: 0x0A84FF) : .white.opacity(0.18), lineWidth: selected ? 2 : 1.5)
    }
}
