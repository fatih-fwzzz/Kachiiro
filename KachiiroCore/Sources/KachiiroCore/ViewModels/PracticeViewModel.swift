import Foundation
import Observation

@MainActor
@Observable
public final class PracticeViewModel {
    public struct PillarSection: Identifiable, Equatable, Sendable {
        public var id: Pillar { pillar }
        public let pillar: Pillar
        public let drills: [DrillKind]
    }

    public static let sessionLength = 20
    public static let emptyScopeMessage = "No items in your study scope"

    /// Set when the last `makeSession` could not produce questions.
    public private(set) var message: String?

    private let seed: SeedData
    private let settings: SettingsStore
    private let repository: ProgressRepository
    private let speech: SpeechPlaying?
    private let inputModeOverride: InputMode?

    public init(
        seed: SeedData, settings: SettingsStore, repository: ProgressRepository,
        speech: SpeechPlaying? = nil, inputModeOverride: InputMode? = nil
    ) {
        self.seed = seed
        self.settings = settings
        self.repository = repository
        self.speech = speech
        self.inputModeOverride = inputModeOverride
    }

    /// Pillars with at least one registered drill, in `Pillar.allCases` order.
    public var sections: [PillarSection] {
        let registered = DrillKind.allCases.filter { QuestionFactoryRegistry.factory(for: $0) != nil }
        return Pillar.allCases.compactMap { pillar in
            let drills = registered.filter { $0.pillar == pillar }
            return drills.isEmpty ? nil : PillarSection(pillar: pillar, drills: drills)
        }
    }

    /// Generates `sessionLength` questions from the current scope. `nil` (and `message`) when there are none.
    public func makeSession(for drill: DrillKind) -> QuizSessionViewModel? {
        guard let factory = QuestionFactoryRegistry.factory(for: drill) else {
            message = "\(drill.title) is not available"
            return nil
        }
        let questions = factory.makeQuestions(count: Self.sessionLength, scope: settings.scope, seed: seed)
        guard !questions.isEmpty else {
            message = Self.emptyScopeMessage
            return nil
        }
        message = nil
        return QuizSessionViewModel(
            questions: questions, initialMode: inputModeOverride ?? settings.inputMode,
            repository: repository, speech: speech
        )
    }

    public func clearMessage() { message = nil }
}
