import Foundation
import SwiftData
import KachiiroCore

@MainActor
final class SwiftDataProgressRepository: ProgressRepository {
    /// A `ModelContext` does not retain its container; keep it alive here.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: ReviewRecord.self, AttemptRecord.self, CanDoRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    private func record(for key: ItemKey) -> ReviewRecord? {
        let raw = key.raw
        var d = FetchDescriptor<ReviewRecord>(predicate: #Predicate { $0.key == raw })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    private func save() {
        do { try context.save() } catch { assertionFailure("SwiftData save failed: \(error)") }
    }

    func record(_ key: ItemKey, pillar: Pillar, correct: Bool, mode: InputMode, at date: Date) {
        let existing = record(for: key)
        let next = SRSScheduler.next(existing?.state, key: key, correct: correct, now: date)
        if let existing {
            existing.apply(next)
        } else {
            context.insert(ReviewRecord(state: next))
        }
        context.insert(AttemptRecord(key: key.raw, pillar: pillar.rawValue, correct: correct, mode: mode.rawValue, date: date))
        save()
    }

    func reviewState(_ key: ItemKey) -> ReviewState? { record(for: key)?.state }

    func dueKeys(now: Date, limit: Int) -> [ItemKey] {
        var d = FetchDescriptor<ReviewRecord>(
            predicate: #Predicate { $0.dueDate <= now }, sortBy: [SortDescriptor(\.dueDate)]
        )
        d.fetchLimit = limit
        return ((try? context.fetch(d)) ?? []).map { ItemKey($0.key) }
    }

    func weakKeys(limit: Int) -> [ItemKey] {
        var d = FetchDescriptor<ReviewRecord>(
            predicate: #Predicate { ($0.box <= 1 && $0.wrongCount > 0) || $0.isBookmarked },
            sortBy: [SortDescriptor(\.box), SortDescriptor(\.dueDate)]
        )
        d.fetchLimit = limit
        return ((try? context.fetch(d)) ?? []).map { ItemKey($0.key) }
    }

    func boxCounts() -> [Int: Int] {
        let d = FetchDescriptor<ReviewRecord>(predicate: #Predicate { $0.correctCount > 0 || $0.wrongCount > 0 })
        return ((try? context.fetch(d)) ?? []).reduce(into: [:]) { $0[$1.box, default: 0] += 1 }
    }

    func setBookmark(_ key: ItemKey, _ on: Bool) {
        if let existing = record(for: key) {
            existing.isBookmarked = on
        } else {
            var s = ReviewState(key: key, lastAnswered: .now, dueDate: .now)
            s.isBookmarked = on
            context.insert(ReviewRecord(state: s))
        }
        save()
    }

    func accuracy(pillar: Pillar, since: Date) -> (correct: Int, total: Int) {
        let raw = pillar.rawValue
        let total = (try? context.fetchCount(FetchDescriptor<AttemptRecord>(
            predicate: #Predicate { $0.pillar == raw && $0.date >= since }
        ))) ?? 0
        let correct = (try? context.fetchCount(FetchDescriptor<AttemptRecord>(
            predicate: #Predicate { $0.pillar == raw && $0.date >= since && $0.correct }
        ))) ?? 0
        return (correct, total)
    }

    func answeredCount(since: Date) -> Int {
        (try? context.fetchCount(FetchDescriptor<AttemptRecord>(predicate: #Predicate { $0.date >= since }))) ?? 0
    }

    func studyDays() -> Set<DateComponents> {
        let dates = ((try? context.fetch(FetchDescriptor<AttemptRecord>())) ?? []).map(\.date)
        return Set(dates.map { Calendar.current.dateComponents([.year, .month, .day], from: $0) })
    }

    func canDoDone() -> Set<Int> {
        Set(((try? context.fetch(FetchDescriptor<CanDoRecord>())) ?? []).map(\.id))
    }

    func setCanDo(_ id: Int, done: Bool) {
        let d = FetchDescriptor<CanDoRecord>(predicate: #Predicate { $0.id == id })
        let existing = (try? context.fetch(d)) ?? []
        if done, existing.isEmpty {
            context.insert(CanDoRecord(id: id))
        } else if !done {
            existing.forEach(context.delete)
        }
        save()
    }

    func resetAll() {
        do {
            try context.delete(model: ReviewRecord.self)
            try context.delete(model: AttemptRecord.self)
            try context.delete(model: CanDoRecord.self)
        } catch {
            assertionFailure("SwiftData reset failed: \(error)")
        }
        save()
    }
}
