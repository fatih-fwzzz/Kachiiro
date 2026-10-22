import Foundation

public enum SRSScheduler {
    /// Days until due per box.
    public static let intervals = [0, 1, 2, 4, 8, 16]

    public static func next(_ state: ReviewState?, key: ItemKey, correct: Bool, now: Date) -> ReviewState {
        var s = state ?? ReviewState(key: key, lastAnswered: now, dueDate: now)
        if correct {
            s.box = min(s.box + 1, intervals.count - 1)
            s.correctCount += 1
        } else {
            s.box = 0
            s.lapses += 1
            s.wrongCount += 1
        }
        s.lastAnswered = now
        s.dueDate = Calendar.current.date(byAdding: .day, value: intervals[s.box], to: now) ?? now
        return s
    }
}
