import Foundation
import Observation

@MainActor
@Observable
public final class DashboardViewModel {
    public struct PillarAccuracy: Identifiable, Equatable, Sendable {
        public var id: Pillar { pillar }
        public let pillar: Pillar
        /// Percent correct over the last 7 days; `nil` when the pillar has no answers.
        public let percent: Int?
        public let answered: Int
    }

    public private(set) var daysLeft: Int?
    public private(set) var answeredToday = 0
    public private(set) var dailyGoal = 30
    public private(set) var dueCount = 0
    public private(set) var streak = 0
    public private(set) var accuracy: [PillarAccuracy] = []

    private let settings: SettingsStore
    private let repository: ProgressRepository
    private let now: () -> Date
    private let calendar: Calendar

    public init(
        settings: SettingsStore, repository: ProgressRepository,
        now: @escaping () -> Date = { Date() }, calendar: Calendar = .current
    ) {
        self.settings = settings
        self.repository = repository
        self.now = now
        self.calendar = calendar
        refresh()
    }

    public func refresh() {
        let current = now()
        let startOfToday = calendar.startOfDay(for: current)
        daysLeft = settings.examDate.map { Self.daysLeft(examDate: $0, now: current, calendar: calendar) }
        dailyGoal = settings.dailyGoal
        answeredToday = repository.answeredCount(since: startOfToday)
        dueCount = repository.dueKeys(now: current, limit: 10_000).count
        streak = Self.streak(studyDays: repository.studyDays(), today: current, calendar: calendar)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: current) ?? current
        let quizzed = Set(DrillKind.allCases.map(\.pillar))
        accuracy = Pillar.allCases.filter(quizzed.contains).map { pillar in
            let a = repository.accuracy(pillar: pillar, since: weekAgo)
            return PillarAccuracy(
                pillar: pillar,
                percent: a.total == 0 ? nil : Int((Double(a.correct) / Double(a.total) * 100).rounded()),
                answered: a.total
            )
        }
    }

    /// 0…1 progress towards the daily goal.
    public var goalProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1, Double(answeredToday) / Double(dailyGoal))
    }

    public var countdownText: String? {
        guard let days = daysLeft else { return nil }
        switch days {
        case 0: return "Exam day"
        case 1: return "1 day left"
        case let d where d > 1: return "\(d) days left"
        case -1: return "Exam was yesterday"
        default: return "Exam was \(-days) days ago"
        }
    }

    /// Whole calendar days from today to the exam day: 0 on the day, negative afterwards.
    public static func daysLeft(examDate: Date, now: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: examDate)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Consecutive study days ending today, or yesterday when nothing has been answered yet today.
    public static func streak(studyDays: Set<DateComponents>, today: Date, calendar: Calendar = .current) -> Int {
        func studied(_ date: Date) -> Bool {
            studyDays.contains(calendar.dateComponents([.year, .month, .day], from: date))
        }
        var day = calendar.startOfDay(for: today)
        if !studied(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), studied(yesterday) else { return 0 }
            day = yesterday
        }
        var count = 0
        while studied(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
