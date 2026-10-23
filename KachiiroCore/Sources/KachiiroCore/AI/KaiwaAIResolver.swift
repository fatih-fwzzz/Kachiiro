import Foundation

/// Decides which engine serves Kaiwa features, falling back to offline rules with a notice.
@MainActor
public final class KaiwaAIResolver {
    private let settings: SettingsStore
    private let keys: APIKeyStore
    private let appleAvailability: @MainActor () -> EngineAvailability
    private let makeAppleClient: @MainActor () -> LanguageModelClient?
    private let makeGeminiClient: (String) -> LanguageModelClient

    public init(
        settings: SettingsStore, keys: APIKeyStore,
        appleAvailability: @escaping @MainActor () -> EngineAvailability,
        makeAppleClient: @escaping @MainActor () -> LanguageModelClient?,
        makeGeminiClient: @escaping (String) -> LanguageModelClient = { GeminiClient(apiKey: $0) }
    ) {
        self.settings = settings
        self.keys = keys
        self.appleAvailability = appleAvailability
        self.makeAppleClient = makeAppleClient
        self.makeGeminiClient = makeGeminiClient
    }

    private var trimmedGeminiKey: String? {
        guard let key = keys.geminiKey()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return nil }
        return key
    }

    public func availability(of engine: KaiwaEngine) -> EngineAvailability {
        switch engine {
        case .rules: .available
        case .appleIntelligence: appleAvailability()
        case .gemini: trimmedGeminiKey == nil ? .unavailable("add a Gemini API key in Settings") : .available
        }
    }

    /// `nil` for offline rules or when the selected engine is unavailable.
    public func service() -> KaiwaAIService? {
        let engine = settings.kaiwaEngine
        guard engine != .rules, availability(of: engine) == .available else { return nil }
        let client: LanguageModelClient?
        switch engine {
        case .rules: client = nil
        case .appleIntelligence: client = makeAppleClient()
        case .gemini: client = trimmedGeminiKey.map(makeGeminiClient)
        }
        return client.map(KaiwaAIService.init(client:))
    }

    public var usesGeneratedContent: Bool {
        settings.kaiwaContent == .generated && service() != nil
    }

    public var engineLabel: String { settings.kaiwaEngine.label }

    public var notice: String? {
        let engine = settings.kaiwaEngine
        if engine == .rules {
            return settings.kaiwaContent == .generated
                ? "AI-generated content needs Apple Intelligence or Gemini. Using bundled content."
                : nil
        }
        if case .unavailable(let reason) = availability(of: engine) {
            return "\(engine.label) unavailable: \(reason). Using offline rules and bundled content."
        }
        return nil
    }
}
