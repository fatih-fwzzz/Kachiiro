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
    }

    public private(set) var due: [Item] = []
    public private(set) var weak: [Item] = []
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
    }

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
            isBookmarked: state?.isBookmarked == true
        )
    }
}
