import Foundation
import Testing
@testable import KachiiroCore

@MainActor
@Suite struct SetupTests {
    @Test func neededOnlyForAFreshInstall() {
        let settings = InMemorySettingsStore()
        let repo = InMemoryProgressRepository()
        #expect(SetupViewModel.isNeeded(settings: settings, repository: repo))

        repo.record(ItemKey("vocab:1:m2w"), pillar: .goi, correct: true, mode: .choice, at: Date())
        #expect(!SetupViewModel.isNeeded(settings: settings, repository: repo))
        #expect(settings.hasCompletedSetup, "existing learners are marked as set up")

        let dated = InMemorySettingsStore()
        dated.examDate = Date()
        #expect(!SetupViewModel.isNeeded(settings: dated, repository: InMemoryProgressRepository()))
    }

    @Test func finishWritesTheChoices() {
        let settings = InMemorySettingsStore()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let vm = SetupViewModel(settings: settings, now: now)
        #expect(vm.examDate > now)
        vm.dailyGoal = 50
        vm.level = .a22
        vm.finish()
        #expect(settings.examDate == vm.examDate && settings.dailyGoal == 50)
        #expect(settings.scope.levels == [.a22] && settings.hasCompletedSetup)

        let noDate = InMemorySettingsStore()
        let other = SetupViewModel(settings: noDate)
        other.hasExamDate = false
        other.finish()
        #expect(noDate.examDate == nil && noDate.hasCompletedSetup)
    }

    @Test func skipOnlyMarksSetupDone() {
        let settings = InMemorySettingsStore()
        SetupViewModel(settings: settings).skip()
        #expect(settings.hasCompletedSetup && settings.examDate == nil && settings.scope == .all)
        #expect(SetupViewModel.minutes(forGoal: 30) == 9)
    }
}
