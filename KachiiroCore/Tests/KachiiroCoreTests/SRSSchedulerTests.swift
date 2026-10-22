import Foundation
import Testing
@testable import KachiiroCore

@Suite struct SRSSchedulerTests {
    let key = ItemKey("vocab:1:m2w")
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func newItemCorrectGoesToBoxOneDueTomorrow() {
        let s = SRSScheduler.next(nil, key: key, correct: true, now: t0)
        #expect(s.box == 1)
        #expect(s.correctCount == 1 && s.wrongCount == 0)
        #expect(s.dueDate == Calendar.current.date(byAdding: .day, value: 1, to: t0))
    }

    @Test func newItemWrongStaysInBoxZeroDueNow() {
        let s = SRSScheduler.next(nil, key: key, correct: false, now: t0)
        #expect(s.box == 0)
        #expect(s.lapses == 1 && s.wrongCount == 1)
        #expect(s.dueDate == t0)
    }

    @Test func wrongFromHigherBoxResets() {
        var s = ReviewState(key: key, box: 3, lastAnswered: t0, dueDate: t0)
        s = SRSScheduler.next(s, key: key, correct: false, now: t0)
        #expect(s.box == 0)
        #expect(s.dueDate == t0)
        #expect(s.lapses == 1)
    }

    @Test func boxIsCappedAtFiveWithSixteenDayInterval() {
        var s: ReviewState?
        for _ in 0..<8 { s = SRSScheduler.next(s, key: key, correct: true, now: t0) }
        #expect(s?.box == 5)
        #expect(s?.dueDate == Calendar.current.date(byAdding: .day, value: 16, to: t0))
    }

    @Test func lapsesAccumulate() {
        var s: ReviewState?
        for _ in 0..<3 {
            s = SRSScheduler.next(s, key: key, correct: true, now: t0)
            s = SRSScheduler.next(s, key: key, correct: false, now: t0)
        }
        #expect(s?.lapses == 3)
        #expect(s?.correctCount == 3)
    }

    @Test func weakDefinition() {
        let t = t0
        #expect(ReviewState(key: key, box: 1, wrongCount: 1, lastAnswered: t, dueDate: t).isWeak)
        #expect(!ReviewState(key: key, box: 2, wrongCount: 1, lastAnswered: t, dueDate: t).isWeak)
        #expect(!ReviewState(key: key, box: 0, wrongCount: 0, lastAnswered: t, dueDate: t).isWeak)
        #expect(ReviewState(key: key, box: 4, lastAnswered: t, dueDate: t, isBookmarked: true).isWeak)
    }
}
