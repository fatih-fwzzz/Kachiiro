import Foundation

@MainActor
public protocol ProgressRepository: AnyObject {
    func record(_ key: ItemKey, pillar: Pillar, correct: Bool, mode: InputMode, at: Date)
    func reviewState(_ key: ItemKey) -> ReviewState?
    func dueKeys(now: Date, limit: Int) -> [ItemKey]
    func weakKeys(limit: Int) -> [ItemKey]
    /// Answered items per Leitner box (0…5); bookmark-only items are not counted.
    func boxCounts() -> [Int: Int]
    func setBookmark(_ key: ItemKey, _ on: Bool)
    func accuracy(pillar: Pillar, since: Date) -> (correct: Int, total: Int)
    func answeredCount(since: Date) -> Int
    func studyDays() -> Set<DateComponents>
    /// Can-do ids are unique across books: 初級1 ids 1…69, 初級2 ids stored as 1001…1078.
    func canDoDone() -> Set<Int>
    func setCanDo(_ id: Int, done: Bool)
    func resetAll()
}
