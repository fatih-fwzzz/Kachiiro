import Foundation
import Testing
@testable import KachiiroCore

@MainActor
@Suite struct InMemoryProgressRepositoryTests {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    func key(_ n: Int) -> ItemKey { ItemKey("vocab:\(n):m2w") }

    @Test func dueAndWeakSetsAfterMixedAnswers() {
        let r = InMemoryProgressRepository()
        r.record(key(1), pillar: .goi, correct: true, mode: .choice, at: t0)   // box 1, due +1d
        r.record(key(2), pillar: .goi, correct: false, mode: .choice, at: t0)  // box 0, due now, weak
        r.record(key(3), pillar: .goi, correct: true, mode: .choice, at: t0)
        r.record(key(3), pillar: .goi, correct: true, mode: .choice, at: t0)   // box 2
        #expect(r.dueKeys(now: t0, limit: 10) == [key(2)])
        #expect(r.weakKeys(limit: 10) == [key(2)])
        let later = t0.addingTimeInterval(86_400 * 2)
        #expect(Set(r.dueKeys(now: later, limit: 10)) == [key(1), key(2), key(3)])
    }

    @Test func bookmarkMakesCorrectItemWeak() {
        let r = InMemoryProgressRepository()
        r.record(key(1), pillar: .goi, correct: true, mode: .choice, at: t0)
        #expect(r.weakKeys(limit: 10).isEmpty)
        r.setBookmark(key(1), true)
        #expect(r.weakKeys(limit: 10) == [key(1)])
        r.record(key(1), pillar: .goi, correct: true, mode: .choice, at: t0)
        #expect(r.reviewState(key(1))?.isBookmarked == true)
        r.setBookmark(key(1), false)
        #expect(r.weakKeys(limit: 10).isEmpty)
    }

    @Test func weakOrderedByBoxThenDue() {
        let r = InMemoryProgressRepository()
        r.record(key(1), pillar: .goi, correct: false, mode: .choice, at: t0.addingTimeInterval(10))
        r.record(key(2), pillar: .goi, correct: false, mode: .choice, at: t0)
        r.record(key(3), pillar: .goi, correct: true, mode: .choice, at: t0)
        r.setBookmark(key(3), true)
        #expect(r.weakKeys(limit: 10) == [key(2), key(1), key(3)])
        #expect(r.weakKeys(limit: 2) == [key(2), key(1)])
    }

    @Test func accuracyCountsOnlyGivenPillarSinceDate() {
        let r = InMemoryProgressRepository()
        r.record(key(1), pillar: .goi, correct: true, mode: .choice, at: t0)
        r.record(key(2), pillar: .goi, correct: false, mode: .choice, at: t0.addingTimeInterval(100))
        r.record(key(3), pillar: .bunpou, correct: true, mode: .choice, at: t0.addingTimeInterval(100))
        let goi = r.accuracy(pillar: .goi, since: t0.addingTimeInterval(50))
        #expect(goi.correct == 0 && goi.total == 1)
        let all = r.accuracy(pillar: .goi, since: t0)
        #expect(all.correct == 1 && all.total == 2)
        #expect(r.accuracy(pillar: .katsuyou, since: t0).total == 0)
        #expect(r.answeredCount(since: t0.addingTimeInterval(50)) == 2)
    }

    @Test func studyDaysAndCanDoAndReset() {
        let r = InMemoryProgressRepository()
        r.record(key(1), pillar: .goi, correct: true, mode: .choice, at: t0)
        r.record(key(2), pillar: .goi, correct: true, mode: .choice, at: t0.addingTimeInterval(3 * 86_400))
        #expect(r.studyDays().count == 2)
        r.setCanDo(1001, done: true)
        r.setCanDo(5, done: true)
        r.setCanDo(5, done: false)
        #expect(r.canDoDone() == [1001])
        r.resetAll()
        #expect(r.studyDays().isEmpty && r.canDoDone().isEmpty && r.dueKeys(now: t0, limit: 5).isEmpty)
    }
}
