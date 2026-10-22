import Foundation
import Testing
@testable import KachiiroCore

@MainActor
@Suite struct DashboardSettingsTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    func days(_ dates: [Date]) -> Set<DateComponents> {
        Set(dates.map { calendar.dateComponents([.year, .month, .day], from: $0) })
    }

    @Test func streakConsecutiveEndingToday() {
        let today = date(2026, 10, 10)
        let s = days([date(2026, 10, 10), date(2026, 10, 9), date(2026, 10, 8)])
        #expect(DashboardViewModel.streak(studyDays: s, today: today, calendar: calendar) == 3)
    }

    @Test func streakSurvivesAnEmptyTodayButNotAnEmptyYesterday() {
        let today = date(2026, 10, 10)
        let yesterdayEnd = days([date(2026, 10, 9), date(2026, 10, 8)])
        #expect(DashboardViewModel.streak(studyDays: yesterdayEnd, today: today, calendar: calendar) == 2)
        let broken = days([date(2026, 10, 8), date(2026, 10, 7)])
        #expect(DashboardViewModel.streak(studyDays: broken, today: today, calendar: calendar) == 0)
    }

    @Test func streakStopsAtGaps() {
        let today = date(2026, 10, 10)
        let s = days([date(2026, 10, 10), date(2026, 10, 9), date(2026, 10, 7), date(2026, 10, 6)])
        #expect(DashboardViewModel.streak(studyDays: s, today: today, calendar: calendar) == 2)
        #expect(DashboardViewModel.streak(studyDays: [], today: today, calendar: calendar) == 0)
    }

    @Test func countdownIncludingExamDayAndPast() {
        let now = date(2026, 10, 10, hour: 23)
        #expect(DashboardViewModel.daysLeft(examDate: date(2026, 10, 17, hour: 1), now: now, calendar: calendar) == 7)
        #expect(DashboardViewModel.daysLeft(examDate: date(2026, 10, 10, hour: 8), now: now, calendar: calendar) == 0)
        #expect(DashboardViewModel.daysLeft(examDate: date(2026, 10, 8), now: now, calendar: calendar) == -2)
    }

    func makeDashboard(_ repo: InMemoryProgressRepository, _ settings: InMemorySettingsStore, now: Date) -> DashboardViewModel {
        DashboardViewModel(settings: settings, repository: repo, now: { now }, calendar: calendar)
    }

    @Test func countdownTexts() {
        let now = date(2026, 10, 10)
        let settings = InMemorySettingsStore()
        let repo = InMemoryProgressRepository()
        #expect(makeDashboard(repo, settings, now: now).countdownText == nil)
        settings.examDate = date(2026, 10, 17)
        #expect(makeDashboard(repo, settings, now: now).countdownText == "7 days left")
        settings.examDate = date(2026, 10, 11)
        #expect(makeDashboard(repo, settings, now: now).countdownText == "1 day left")
        settings.examDate = date(2026, 10, 10)
        #expect(makeDashboard(repo, settings, now: now).countdownText == "Exam day")
        settings.examDate = date(2026, 10, 8)
        #expect(makeDashboard(repo, settings, now: now).countdownText == "Exam was 2 days ago")
    }

    @Test func accuracyHasNoValueWithoutAnswersAndCountsLastWeekOnly() {
        let now = date(2026, 10, 10)
        let repo = InMemoryProgressRepository(calendar: calendar)
        let settings = InMemorySettingsStore()
        let empty = makeDashboard(repo, settings, now: now)
        #expect(empty.accuracy.allSatisfy { $0.percent == nil })
        #expect(!empty.accuracy.contains { $0.pillar == .kaiwa })

        repo.record(ItemKey("vocab:1:m2w"), pillar: .goi, correct: true, mode: .choice, at: date(2026, 10, 9))
        repo.record(ItemKey("vocab:2:m2w"), pillar: .goi, correct: false, mode: .choice, at: date(2026, 10, 10))
        repo.record(ItemKey("vocab:3:m2w"), pillar: .goi, correct: false, mode: .choice, at: date(2026, 9, 20))
        let vm = makeDashboard(repo, settings, now: now)
        let goi = vm.accuracy.first { $0.pillar == .goi }
        #expect(goi?.percent == 50 && goi?.answered == 2)
        #expect(vm.accuracy.first { $0.pillar == .katsuyou }?.percent == nil)
        #expect(vm.answeredToday == 1)
        #expect(vm.streak == 2)
    }

    @Test func goalProgressAndDueCount() {
        let now = date(2026, 10, 10)
        let repo = InMemoryProgressRepository()
        let settings = InMemorySettingsStore()
        settings.dailyGoal = 10
        for n in 0..<4 { repo.record(ItemKey("vocab:\(n):m2w"), pillar: .goi, correct: false, mode: .choice, at: now) }
        let vm = makeDashboard(repo, settings, now: now)
        #expect(vm.answeredToday == 4 && vm.goalProgress == 0.4)
        #expect(vm.dueCount == 4)
        settings.dailyGoal = 2
        vm.refresh()
        #expect(vm.goalProgress == 1)
    }

    @Test func scopeChangesAreReflectedAndPersisted() {
        let store = InMemorySettingsStore()
        let vm = SettingsViewModel(store: store, repository: InMemoryProgressRepository())
        #expect(vm.scope == .all)
        vm.setLevel(.a1, selected: false)
        #expect(vm.scope.levels == [.a21, .a22] && store.scope.levels == [.a21, .a22])
        vm.setLevel(.a21, selected: false)
        vm.setLevel(.a22, selected: false)
        #expect(vm.scope.levels == [.a22], "the last level cannot be switched off")
        vm.setLessonRangeLimited(true)
        #expect(store.scope.lessonRange == 1...18)
        vm.setLessonStart(5)
        vm.setLessonEnd(9)
        #expect(store.scope.lessonRange == 5...9)
        vm.setLessonStart(12)
        #expect(vm.lessonStart == 12 && vm.lessonEnd == 12)
        vm.setLessonEnd(3)
        #expect(vm.lessonStart == 3 && vm.lessonEnd == 3)
        vm.setLessonEnd(99)
        #expect(vm.lessonEnd == 18)
        vm.setLessonRangeLimited(false)
        #expect(store.scope.lessonRange == nil)
    }

    @Test func goalModeAndExamDateWriteThrough() {
        let store = InMemorySettingsStore()
        let vm = SettingsViewModel(store: store, repository: InMemoryProgressRepository())
        vm.setDailyGoal(500)
        #expect(store.dailyGoal == 200)
        vm.setDailyGoal(1)
        #expect(store.dailyGoal == 10)
        vm.setInputMode(.typing)
        #expect(store.inputMode == .typing)
        let d = date(2026, 10, 17)
        vm.setExamDate(d)
        #expect(store.examDate == d)
        vm.setExamDate(nil)
        #expect(store.examDate == nil)
    }

    @Test func resetProgressClearsRepository() {
        let repo = InMemoryProgressRepository()
        repo.record(ItemKey("vocab:1:m2w"), pillar: .goi, correct: false, mode: .choice, at: Date())
        SettingsViewModel(store: InMemorySettingsStore(), repository: repo).resetProgress()
        #expect(repo.attempts.isEmpty && repo.weakKeys(limit: 5).isEmpty)
    }
}
