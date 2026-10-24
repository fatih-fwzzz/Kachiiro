import Foundation
import Testing
@testable import KachiiroCore

@MainActor
@Suite struct ReviewStrengthTests {
    @Test func boxCountsSkipBookmarkOnlyItems() {
        let repo = InMemoryProgressRepository()
        let now = Date()
        repo.record(ItemKey("vocab:1:m2w"), pillar: .goi, correct: false, mode: .choice, at: now)
        repo.record(ItemKey("vocab:2:m2w"), pillar: .goi, correct: true, mode: .choice, at: now)
        repo.setBookmark(ItemKey("vocab:3:m2w"), true)
        let counts = repo.boxCounts()
        #expect(counts.values.reduce(0, +) == 2)
        #expect(counts[repo.reviewState(ItemKey("vocab:2:m2w"))!.box] != nil)
    }

    @Test func reviewExposesStrengthAndReasons() {
        let now = Date()
        let repo = InMemoryProgressRepository()
        repo.record(ItemKey("vocab:1:m2w"), pillar: .goi, correct: false, mode: .choice, at: now.addingTimeInterval(-86_400))
        let vm = ReviewViewModel(repository: repo, seed: TestSeed.shared, settings: InMemorySettingsStore(), now: { now })
        #expect(vm.strength.counts.count == 6 && vm.strength.total == 1)
        #expect(vm.estimatedMinutes == 1)
        let item = (vm.due + vm.weak).first { $0.key == ItemKey("vocab:1:m2w") }
        #expect(item?.reason.hasPrefix("Due now · missed 1×") == true || item?.reason.hasPrefix("Weak") == true)
    }

    @Test func reasonTexts() {
        let now = Date()
        var state = ReviewState(key: ItemKey("vocab:1:m2w"), box: 1, correctCount: 1, wrongCount: 2,
                                lastAnswered: now, dueDate: now.addingTimeInterval(-60))
        #expect(ReviewViewModel.reason(state, now: now) == "Due now · missed 2×")
        state.dueDate = now.addingTimeInterval(3600)
        #expect(ReviewViewModel.reason(state, now: now) == "Weak · 1 of 3 right")
        state = ReviewState(key: state.key, box: 3, correctCount: 3, lastAnswered: now,
                            dueDate: now.addingTimeInterval(3600), isBookmarked: true)
        #expect(ReviewViewModel.reason(state, now: now) == "Saved")
    }
}
