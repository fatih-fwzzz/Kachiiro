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
    /// `true` while AI-generated questions are being fetched.
    public private(set) var isGenerating = false

    private let seed: SeedData
    private let settings: SettingsStore
    private let repository: ProgressRepository
    private let speech: SpeechPlaying?
    private let inputModeOverride: InputMode?
    private let aiResolver: KaiwaAIResolver?

    public init(
        seed: SeedData, settings: SettingsStore, repository: ProgressRepository,
        speech: SpeechPlaying? = nil, inputModeOverride: InputMode? = nil, aiResolver: KaiwaAIResolver? = nil
    ) {
        self.seed = seed
        self.settings = settings
        self.repository = repository
        self.speech = speech
        self.inputModeOverride = inputModeOverride
        self.aiResolver = aiResolver
    }

    /// Pillars with at least one registered drill, in `Pillar.allCases` order.
    public var sections: [PillarSection] {
        let registered = DrillKind.allCases.filter { QuestionFactoryRegistry.factory(for: $0) != nil }
        return Pillar.allCases.compactMap { pillar in
            let drills = registered.filter { $0.pillar == pillar }
            return drills.isEmpty ? nil : PillarSection(pillar: pillar, drills: drills)
        }
    }

    /// Why AI features fell back to offline rules, if they did.
    public var kaiwaNotice: String? { aiResolver?.notice }

    public var kaiwaEngineLabel: String { aiResolver?.engineLabel ?? KaiwaEngine.rules.label }

    public func usesGeneratedContent(for drill: DrillKind) -> Bool {
        drill.pillar == .kaiwa && aiResolver?.usesGeneratedContent == true
    }

    private func initialMode(for drill: DrillKind) -> InputMode {
        inputModeOverride ?? (drill == .keigo ? .typing : settings.inputMode)
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
            questions: questions, initialMode: initialMode(for: drill),
            repository: repository, speech: speech, judge: drill.pillar == .kaiwa ? aiResolver?.service() : nil
        )
    }

    /// Asks the selected AI engine for a fresh set; `nil` (and `message`) on failure.
    public func makeGeneratedSession(for drill: DrillKind) async -> QuizSessionViewModel? {
        guard let service = aiResolver?.service() else {
            message = aiResolver?.notice ?? "AI generation is not available"
            return nil
        }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let questions: [QuizQuestion]
            switch drill {
            case .keigo: questions = try await service.generateKeigoQuestions(count: 10)
            case .uchiSoto: questions = try await service.generateUchiSotoQuestions(count: 10)
            default:
                message = "\(drill.title) cannot be generated"
                return nil
            }
            message = nil
            return QuizSessionViewModel(
                questions: questions, initialMode: initialMode(for: drill),
                repository: repository, speech: speech, judge: service
            )
        } catch {
            message = "Couldn't generate questions: \(error.localizedDescription)"
            return nil
        }
    }

    public func clearMessage() { message = nil }
}
