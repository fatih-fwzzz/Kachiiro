import Foundation

public enum KaiwaEngine: String, CaseIterable, Codable, Sendable {
    case rules, appleIntelligence, gemini

    public var label: String {
        switch self {
        case .rules: "Offline rules"
        case .appleIntelligence: "Apple Intelligence (on-device)"
        case .gemini: "Gemini"
        }
    }
}

public enum KaiwaContentSource: String, CaseIterable, Codable, Sendable {
    case bundled, generated

    public var label: String {
        switch self {
        case .bundled: "Bundled + Irodori"
        case .generated: "AI-generated"
        }
    }
}
