import Foundation
import Testing
@testable import KachiiroCore

@MainActor
@Suite struct TodayPlanTests {
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

    func row(_ pillar: Pillar, _ percent: Int?, answered: Int? = nil) -> DashboardViewModel.PillarAccuracy {
        .init(pillar: pillar, percent: percent, answered: answered ?? (percent == nil ? 0 : 10))
    }

    @Test func trackEndsOnANearExamDay() {
        let today = date(2026, 10, 24)
        let studied = days([date(2026, 10, 21), date(2026, 10, 23)])
        let track = DashboardViewModel.track(studyDays: studied, daysLeft: 4, today: today, calendar: calendar)
        #expect(track.count == 7)
        #expect(track.map(\.status) == [.missed, .studied, .today, .upcoming, .upcoming, .upcoming, .upcoming])
        #expect(track.last?.isExamDay == true && track.filter(\.isExamDay).count == 1)
        #expect(track.last?.date == calendar.startOfDay(for: date(2026, 10, 28)))
    }

    @Test func trackShowsTheLastWeekWithoutANearExam() {
        let today = date(2026, 10, 24)
        let studied = days([today])
        for left in [nil, 30, -2] as [Int?] {
            let track = DashboardViewModel.track(studyDays: studied, daysLeft: left, today: today, calendar: calendar)
            #expect(track.count == 7 && track.last?.status == .studied)
            #expect(track.allSatisfy { !$0.isExamDay && $0.status != .upcoming })
        }
        let examToday = DashboardViewModel.track(studyDays: [], daysLeft: 0, today: today, calendar: calendar)
        #expect(examToday.last?.isExamDay == true && examToday.last?.status == .today)
    }

    @Test func planPutsDueReviewFirstThenWeakestThenUnpractised() {
        let accuracy = [row(.katsuyou, 72), row(.goi, 48), row(.bunpou, 66), row(.choukai, nil), row(.kaiwa, nil)]
        let plan = DashboardViewModel.plan(dueCount: 35, accuracy: accuracy)
        #expect(plan.map(\.kind) == [
            .review(count: 20),
            .drill(.vocab, reason: .weakest(percent: 48)),
            .drill(.sentenceListening, reason: .notPractised),
        ])
        #expect(plan[0].minutes == 6 && plan[1].minutes == 6)
    }

    @Test func planWithoutReviewOrHistoryStartsAtTheFirstPillars() {
        let fresh = Pillar.allCases.map { row($0, nil) }
        let plan = DashboardViewModel.plan(dueCount: 0, accuracy: fresh)
        #expect(plan.map(\.kind) == [
            .drill(.verbForms, reason: .notPractised),
            .drill(.vocab, reason: .notPractised),
            .drill(.patternRecognition, reason: .notPractised),
        ])
    }

    @Test func aStrongPillarIsNeverCalledWeakest() {
        let accuracy = [row(.katsuyou, nil), row(.goi, 100), row(.bunpou, nil), row(.choukai, nil), row(.kaiwa, nil)]
        let plan = DashboardViewModel.plan(dueCount: 0, accuracy: accuracy)
        #expect(plan.map(\.kind) == [
            .drill(.verbForms, reason: .notPractised),
            .drill(.patternRecognition, reason: .notPractised),
            .drill(.sentenceListening, reason: .notPractised),
        ])
        let allStrong = Pillar.allCases.map { row($0, 90) }
        #expect(DashboardViewModel.plan(dueCount: 0, accuracy: allStrong).first?.kind
                == .drill(.verbForms, reason: .keepSharp(percent: 90)))
    }

    @Test func planKeepsSharpWhenEveryPillarWasPractised() {
        let accuracy = [row(.katsuyou, 90), row(.goi, 61), row(.bunpou, 55), row(.choukai, 80), row(.kaiwa, 70)]
        let plan = DashboardViewModel.plan(dueCount: 2, accuracy: accuracy)
        #expect(plan.map(\.kind) == [
            .review(count: 2),
            .drill(.patternRecognition, reason: .weakest(percent: 55)),
            .drill(.vocab, reason: .keepSharp(percent: 61)),
        ])
        #expect(plan[0].minutes == 1)
    }

    @Test func dashboardExposesTrackPlanAndWeekAccuracy() {
        let now = date(2026, 10, 24)
        let repo = InMemoryProgressRepository(calendar: calendar)
        let settings = InMemorySettingsStore()
        settings.examDate = date(2026, 10, 29)
        repo.record(ItemKey("vocab:1:m2w"), pillar: .goi, correct: true, mode: .choice, at: date(2026, 10, 23))
        repo.record(ItemKey("vocab:2:m2w"), pillar: .goi, correct: false, mode: .choice, at: date(2026, 10, 24))
        repo.record(ItemKey("verb:3:te"), pillar: .katsuyou, correct: true, mode: .choice, at: date(2026, 10, 24))
        let vm = DashboardViewModel(settings: settings, repository: repo, now: { now }, calendar: calendar)
        #expect(vm.weekAccuracy == 67)
        #expect(vm.track.last?.isExamDay == true && vm.track.count == 7)
        #expect(vm.plan.first?.kind == .review(count: vm.dueCount))
        #expect(vm.plan.contains { $0.kind == .drill(.vocab, reason: .weakest(percent: 50)) })
        #expect(vm.planMinutes == vm.plan.reduce(0) { $0 + $1.minutes })
    }
}
