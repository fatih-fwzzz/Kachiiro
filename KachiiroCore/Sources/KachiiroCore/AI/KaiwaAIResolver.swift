import Foundation

/// Decides which engine serves Kaiwa features, falling back to offline rules with a notice.
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

    /// AI engines the learner can pick: Apple Intelligence only when this device has it.
    public var engineChoices: [KaiwaEngine] {
        [.appleIntelligence, .gemini].filter { availability(of: $0) == .available }
    }

    /// `nil` when no AI engine is available (offline rules).
    public func service() -> KaiwaAIService? {
        let client: LanguageModelClient?
        switch activeEngine {
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

    public var usesGeneratedContent: Bool {
        settings.kaiwaContent == .generated && service() != nil
    }

    public var engineLabel: String { activeEngine.label }

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
