import Foundation
import Observation

/// First run: the exam date, a daily goal and the book, so Today can build a plan straight away.
@MainActor
@Observable
public final class SetupViewModel {
    public static let goalChoices = [20, 30, 50]

    public var examDate: Date
    public var hasExamDate = true
    public var dailyGoal = 30
    public var level: Level = .a21

    private let settings: SettingsStore

    public init(settings: SettingsStore, now: Date = Date(), calendar: Calendar = .current) {
        self.settings = settings
        examDate = settings.examDate ?? calendar.date(byAdding: .day, value: 7, to: now) ?? now
        dailyGoal = settings.dailyGoal
    }

    /// Shown only to someone who has neither set an exam date nor answered anything.
    public static func isNeeded(settings: SettingsStore, repository: ProgressRepository) -> Bool {
        guard !settings.hasCompletedSetup else { return false }
        if settings.examDate != nil || !repository.studyDays().isEmpty {
            settings.hasCompletedSetup = true
            return false
        }
        return true
    }

    /// Minutes a daily goal takes at about 18 s per answer.
    public static func minutes(forGoal goal: Int) -> Int {
        max(1, Int((Double(goal) * 18 / 60).rounded()))
    }

    public func finish() {
        settings.examDate = hasExamDate ? examDate : nil
        settings.dailyGoal = dailyGoal
        settings.scope = StudyScope(levels: [level], lessonRange: settings.scope.lessonRange)
        settings.hasCompletedSetup = true
    }

    public func skip() {
        settings.hasCompletedSetup = true
    }
}
