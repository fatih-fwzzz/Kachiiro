import Foundation

/// What the AI is asked to do. The on-device model is trusted only for low-stakes text: it writes keigo
/// exercises poorly and has accepted wrong keigo as correct, so questions and grading stay on Gemini.
public enum AITask: Sendable, CaseIterable {
    /// Short phrases for shadowing.
    case shadowing
    /// Open conversation where the AI plays a part and nothing is graded.
    case conversation
    /// Keigo and uchi/soto exercises.
    case questions
    /// Judging answers and reviewing roleplay lines.
    case checking

    public var allowsAppleIntelligence: Bool { self == .shadowing || self == .conversation }
}

/// Decides which engine serves each AI task, falling back to offline rules with a notice.
@MainActor
public final class KaiwaAIResolver {
    private let settings: SettingsStore
    private let keys: APIKeyStore
    private let appleAvailability: @MainActor () -> EngineAvailability
    private let makeAppleClient: @MainActor () -> LanguageModelClient?
    private let makeGeminiClient: (String) -> LanguageModelClient
    private let makeGeminiLive: @MainActor (String) -> LiveRoleplayPartner
    private let readings: JapaneseReading

    public init(
        settings: SettingsStore, keys: APIKeyStore,
        appleAvailability: @escaping @MainActor () -> EngineAvailability,
        makeAppleClient: @escaping @MainActor () -> LanguageModelClient?,
        makeGeminiClient: @escaping (String) -> LanguageModelClient = { GeminiClient(apiKey: $0) },
        makeGeminiLive: @escaping @MainActor (String) -> LiveRoleplayPartner = { GeminiLiveClient(apiKey: $0) },
        readings: JapaneseReading = JapaneseReading()
    ) {
        self.readings = readings
        self.settings = settings
        self.keys = keys
        self.appleAvailability = appleAvailability
        self.makeAppleClient = makeAppleClient
        self.makeGeminiClient = makeGeminiClient
        self.makeGeminiLive = makeGeminiLive
    }

    private var trimmedGeminiKey: String? {
        guard let key = keys.geminiKey()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return nil }
        return key
    }

    public func availability(of engine: KaiwaEngine) -> EngineAvailability {
        switch engine {
        case .rules: .available
        case .appleIntelligence: appleAvailability()
        case .gemini: trimmedGeminiKey == nil ? .unavailable("no Gemini API key in this build") : .available
        case .automatic:
            availability(of: .appleIntelligence) == .available || availability(of: .gemini) == .available
                ? .available : .unavailable("no AI engine is available")
        }
    }

    /// The engine in use: the chosen one when it is available, else Apple Intelligence, else Gemini,
    /// else offline rules. An explicit `rules` choice always stays offline.
    public var activeEngine: KaiwaEngine {
        let chosen = settings.kaiwaEngine
        if chosen == .rules { return .rules }
        if chosen != .automatic, availability(of: chosen) == .available { return chosen }
        if availability(of: .appleIntelligence) == .available { return .appleIntelligence }
        if availability(of: .gemini) == .available { return .gemini }
        return .rules
    }

    /// The engine for `task`: `activeEngine` when the task may use Apple Intelligence, else Gemini or offline rules.
    public func engine(for task: AITask) -> KaiwaEngine {
        if task.allowsAppleIntelligence { return activeEngine }
        if settings.kaiwaEngine == .rules { return .rules }
        return availability(of: .gemini) == .available ? .gemini : .rules
    }

    /// AI engines the learner can pick: Apple Intelligence only when this device has it.
    public var engineChoices: [KaiwaEngine] {
        [.appleIntelligence, .gemini].filter { availability(of: $0) == .available }
    }

    /// `nil` when no AI engine can serve `task` (offline rules).
    public func service(for task: AITask) -> KaiwaAIService? {
        let client: LanguageModelClient?
        switch engine(for: task) {
        case .rules, .automatic: client = nil
        case .appleIntelligence: client = makeAppleClient()
        case .gemini: client = trimmedGeminiKey.map(makeGeminiClient)
        }
        return client.map { KaiwaAIService(client: $0, readings: readings) }
    }

    /// A Gemini Live voice partner; `nil` unless Gemini is the active engine and content is AI-generated.
    public func liveRoleplayPartner() -> LiveRoleplayPartner? {
        guard activeEngine == .gemini, settings.kaiwaContent == .generated, let key = trimmedGeminiKey else {
            return nil
        }
        return makeGeminiLive(key)
    }

    /// AI-generated content is on and an engine can serve `task`.
    public func usesGeneratedContent(for task: AITask) -> Bool {
        settings.kaiwaContent == .generated && service(for: task) != nil
    }

    /// Why `task` runs offline or on a different engine than chosen, if it does.
    public func notice(for task: AITask) -> String? {
        if task.allowsAppleIntelligence || settings.kaiwaEngine == .rules { return notice }
        return engine(for: task) == .rules
            ? "AI isn’t available right now. Using offline checks and bundled content."
            : nil
    }

    /// The notice for the engine choice in Settings (shadowing and conversation).
    public var notice: String? {
        let chosen = settings.kaiwaEngine
        let active = activeEngine
        if chosen == .rules {
            return settings.kaiwaContent == .generated
                ? "AI-generated content needs Apple Intelligence or Gemini. Using bundled content."
                : nil
        }
        if active == .rules {
            return "AI isn’t available right now. Using offline checks and bundled content."
        }
        if chosen != .automatic, chosen != active, case .unavailable(let reason) = availability(of: chosen) {
            return "\(chosen.label) isn’t available (\(reason)), so \(active.label) is used."
        }
        return nil
    }
}
