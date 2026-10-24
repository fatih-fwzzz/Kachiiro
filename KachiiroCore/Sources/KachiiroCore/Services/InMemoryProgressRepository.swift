import Foundation

@MainActor
public final class InMemoryProgressRepository: ProgressRepository {
    public struct Attempt: Equatable, Sendable {
        public let key: ItemKey
        public let pillar: Pillar
        public let correct: Bool
        public let mode: InputMode
        public let date: Date
    }

    public private(set) var attempts: [Attempt] = []
    private var states: [ItemKey: ReviewState] = [:]
    private var canDo: Set<Int> = []
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func record(_ key: ItemKey, pillar: Pillar, correct: Bool, mode: InputMode, at date: Date) {
        attempts.append(Attempt(key: key, pillar: pillar, correct: correct, mode: mode, date: date))
        var next = SRSScheduler.next(states[key], key: key, correct: correct, now: date)
        next.isBookmarked = states[key]?.isBookmarked ?? false
        states[key] = next
    }

    public func reviewState(_ key: ItemKey) -> ReviewState? { states[key] }

    public func dueKeys(now: Date, limit: Int) -> [ItemKey] {
        states.values.filter { $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(limit).map(\.key)
    }

    public func weakKeys(limit: Int) -> [ItemKey] {
        states.values.filter(\.isWeak)
            .sorted { ($0.box, $0.dueDate) < ($1.box, $1.dueDate) }
            .prefix(limit).map(\.key)
    }

    public func boxCounts() -> [Int: Int] {
        states.values.filter { $0.correctCount + $0.wrongCount > 0 }
            .reduce(into: [:]) { $0[$1.box, default: 0] += 1 }
    }

    public func setBookmark(_ key: ItemKey, _ on: Bool) {
        var s = states[key] ?? ReviewState(key: key, lastAnswered: .now, dueDate: .now)
        s.isBookmarked = on
        states[key] = s
    }

    public func accuracy(pillar: Pillar, since: Date) -> (correct: Int, total: Int) {
        let rows = attempts.filter { $0.pillar == pillar && $0.date >= since }
        return (rows.filter(\.correct).count, rows.count)
    }

    public func answeredCount(since: Date) -> Int { attempts.filter { $0.date >= since }.count }

    public func studyDays() -> Set<DateComponents> {
        Set(attempts.map { calendar.dateComponents([.year, .month, .day], from: $0.date) })
    }

    public func canDoDone() -> Set<Int> { canDo }

    public func setCanDo(_ id: Int, done: Bool) {
        if done { canDo.insert(id) } else { canDo.remove(id) }
    }

    public func resetAll() {
        attempts = []
        states = [:]
        canDo = []
    }
}
