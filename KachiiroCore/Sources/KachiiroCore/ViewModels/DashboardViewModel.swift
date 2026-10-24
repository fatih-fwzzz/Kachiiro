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

    /// One day on the Today screen's track: the days before the exam, or the last week when no exam is near.
    public struct TrackDay: Identifiable, Equatable, Sendable {
        public enum Status: Equatable, Sendable { case studied, missed, today, upcoming }
        public var id: Date { date }
        public let date: Date
        public let status: Status
        public let isExamDay: Bool
    }

    /// One step of today's suggested session.
    public struct PlanStep: Identifiable, Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            /// Due review cards, capped at `reviewBatch`.
            case review(count: Int)
            case drill(DrillKind, reason: Reason)
        }

        public enum Reason: Equatable, Sendable {
            /// Lowest 7-day accuracy, in percent.
            case weakest(percent: Int)
            /// No answers in the last 7 days.
            case notPractised
            /// Second-lowest accuracy, when every pillar was practised.
            case keepSharp(percent: Int)
        }

        public var id: String {
            switch kind {
            case .review: "review"
            case .drill(let drill, _): "drill.\(drill.rawValue)"
            }
        }

        public let kind: Kind
        public let minutes: Int
    }

    public static let reviewBatch = 20
    /// A pillar at or above this 7-day accuracy is not called weak.
    public static let weakThreshold = 80
    /// Rough pace used for time estimates.
    static let secondsPerQuestion = 18.0

    public private(set) var daysLeft: Int?
    public private(set) var answeredToday = 0
    public private(set) var dailyGoal = 30
    public private(set) var dueCount = 0
    public private(set) var streak = 0
    public private(set) var accuracy: [PillarAccuracy] = []
    /// Percent correct over the last 7 days across all pillars; `nil` without answers.
    public private(set) var weekAccuracy: Int?
    public private(set) var track: [TrackDay] = []
    public private(set) var plan: [PlanStep] = []

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
        let studyDays = repository.studyDays()
        streak = Self.streak(studyDays: studyDays, today: current, calendar: calendar)
        let week = Self.weekAccuracy(repository: repository, now: current, calendar: calendar)
        accuracy = week.pillars
        weekAccuracy = week.overall
        track = Self.track(studyDays: studyDays, daysLeft: daysLeft, today: current, calendar: calendar)
        plan = Self.plan(dueCount: dueCount, accuracy: accuracy)
    }

    /// Per-pillar and overall percent correct over the 7 days before `now`.
    public static func weekAccuracy(
        repository: ProgressRepository, now: Date, calendar: Calendar = .current
    ) -> (pillars: [PillarAccuracy], overall: Int?) {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let quizzed = Set(DrillKind.allCases.map(\.pillar))
        var correct = 0, total = 0
        let pillars = Pillar.allCases.filter(quizzed.contains).map { pillar in
            let a = repository.accuracy(pillar: pillar, since: weekAgo)
            correct += a.correct
            total += a.total
            return PillarAccuracy(pillar: pillar, percent: percent(a.correct, of: a.total), answered: a.total)
        }
        return (pillars, percent(correct, of: total))
    }

    static func percent(_ part: Int, of whole: Int) -> Int? {
        whole == 0 ? nil : Int((Double(part) / Double(whole) * 100).rounded())
    }

    /// Seven days ending on the exam day when it is at most six days away, else the last seven days ending today.
    public static func track(
        studyDays: Set<DateComponents>, daysLeft: Int?, today: Date, calendar: Calendar = .current
    ) -> [TrackDay] {
        let start = calendar.startOfDay(for: today)
        let examOffset = daysLeft.flatMap { (0...6).contains($0) ? $0 : nil }
        let lastOffset = examOffset ?? 0
        return ((lastOffset - 6)...lastOffset).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let studied = studyDays.contains(calendar.dateComponents([.year, .month, .day], from: date))
            let status: TrackDay.Status
            switch offset {
            case ..<0: status = studied ? .studied : .missed
            case 0: status = studied ? .studied : .today
            default: status = .upcoming
            }
            return TrackDay(date: date, status: status, isExamDay: examOffset == offset)
        }
    }

    /// Up to three steps: due review first, then the weakest pillar (under `weakThreshold`),
    /// then pillars not practised this week, then the lowest of the rest to keep sharp.
    public static func plan(dueCount: Int, accuracy: [PillarAccuracy]) -> [PlanStep] {
        var steps: [PlanStep] = []
        if dueCount > 0 {
            let count = min(dueCount, reviewBatch)
            steps.append(PlanStep(kind: .review(count: count), minutes: minutes(questions: count)))
        }
        let drillMinutes = minutes(questions: PracticeViewModel.sessionLength)
        let ranked = accuracy.compactMap { a in a.percent.map { (pillar: a.pillar, percent: $0) } }
            .sorted { $0.percent < $1.percent }
        var used = Set<Pillar>()
        if let weakest = ranked.first, weakest.percent < weakThreshold {
            used.insert(weakest.pillar)
            steps.append(PlanStep(kind: .drill(weakest.pillar.planDrill, reason: .weakest(percent: weakest.percent)),
                                  minutes: drillMinutes))
        }
        for a in accuracy where a.answered == 0 && !used.contains(a.pillar) && steps.count < 3 {
            used.insert(a.pillar)
            steps.append(PlanStep(kind: .drill(a.pillar.planDrill, reason: .notPractised), minutes: drillMinutes))
        }
        if steps.count < 3, let next = ranked.first(where: { !used.contains($0.pillar) }) {
            steps.append(PlanStep(kind: .drill(next.pillar.planDrill, reason: .keepSharp(percent: next.percent)),
                                  minutes: drillMinutes))
        }
        return Array(steps.prefix(3))
    }

    static func minutes(questions: Int) -> Int {
        max(1, Int((Double(questions) * secondsPerQuestion / 60).rounded(.up)))
    }

    /// Total minutes of today's plan.
    public var planMinutes: Int { plan.reduce(0) { $0 + $1.minutes } }

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
