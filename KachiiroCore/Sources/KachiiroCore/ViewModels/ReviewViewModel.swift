import Foundation
import Observation

@MainActor
@Observable
public final class ReviewViewModel {
    public struct Item: Identifiable, Equatable, Sendable {
        public var id: ItemKey { key }
        public let key: ItemKey
        public let title: String
        public let subtitle: String
        public let isBookmarked: Bool
        /// The pillar the item belongs to; `nil` when the item no longer exists.
        public var pillar: Pillar? = nil
        /// Why the item is in the queue ("Due now · missed 2×", "Weak · 1 of 3 right").
        public var reason: String = ""
    }

    /// Memory strength: answered items per Leitner box, from new (0) to mastered (5).
    public struct Strength: Equatable, Sendable {
        public let counts: [Int]
        public var total: Int { counts.reduce(0, +) }
        public static let labels = ["New", "Learning", "Familiar", "Known", "Strong", "Mastered"]
    }

    public private(set) var due: [Item] = []
    public private(set) var weak: [Item] = []
    public private(set) var strength = Strength(counts: Array(repeating: 0, count: 6))
    public static let listLimit = 100

    private let repository: ProgressRepository
    private let seed: SeedData
    private let settings: SettingsStore
    private let speech: SpeechPlaying?
    private let now: () -> Date

    public init(
        repository: ProgressRepository, seed: SeedData, settings: SettingsStore,
        speech: SpeechPlaying? = nil, now: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.seed = seed
        self.settings = settings
        self.speech = speech
        self.now = now
        refresh()
    }

    public var totalCount: Int { allKeys.count }

    public func refresh() {
        due = repository.dueKeys(now: now(), limit: Self.listLimit).map(item)
        weak = repository.weakKeys(limit: Self.listLimit).map(item)
        let boxes = repository.boxCounts()
        strength = Strength(counts: (0...5).map { boxes[$0] ?? 0 })
    }

    /// About 18 s per card.
    public var estimatedMinutes: Int { max(1, Int((Double(totalCount) * 18 / 60).rounded(.up))) }

    public func toggleBookmark(_ key: ItemKey) {
        let on = repository.reviewState(key)?.isBookmarked != true
        repository.setBookmark(key, on)
        refresh()
    }

    /// Due items first, then weak ones, each key once.
    public var allKeys: [ItemKey] {
        var seen = Set<ItemKey>()
        return (due + weak).map(\.key).filter { seen.insert($0).inserted }
    }

    /// Builds a session over `keys`, skipping keys whose item no longer exists. `nil` when nothing remains.
    public func makeSession(keys: [ItemKey]? = nil) -> QuizSessionViewModel? {
        let questions = (keys ?? allKeys).compactMap { QuestionFactoryRegistry.question(for: $0, seed: seed) }
        guard !questions.isEmpty else { return nil }
        return QuizSessionViewModel(
            questions: questions, initialMode: settings.inputMode, repository: repository, speech: speech, now: now
        )
    }

    private func item(_ key: ItemKey) -> Item {
        let state = repository.reviewState(key)
        let question = QuestionFactoryRegistry.question(for: key, seed: seed)
        let subtitle = state.map { "Box \($0.box) · ✓\($0.correctCount) ✗\($0.wrongCount)" } ?? ""
        return Item(
            key: key, title: question?.promptBody ?? key.raw,
            subtitle: [question?.promptTitle, subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
            isBookmarked: state?.isBookmarked == true,
            pillar: question?.pillar,
            reason: state.map { Self.reason($0, now: now()) } ?? ""
        )
    }

    static func reason(_ state: ReviewState, now: Date) -> String {
        let answered = state.correctCount + state.wrongCount
        if state.dueDate <= now {
            return state.wrongCount > 0 ? "Due now · missed \(state.wrongCount)×" : "Due now"
        }
        if state.box <= 1 && state.wrongCount > 0 { return "Weak · \(state.correctCount) of \(answered) right" }
        return state.isBookmarked ? "Saved" : ""
    }
}
