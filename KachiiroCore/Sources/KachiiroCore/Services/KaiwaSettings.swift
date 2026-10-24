import Foundation

/// `automatic` (the default) uses Apple Intelligence when the device has it, else Gemini.
/// `rules` forces the offline checks; it is not offered in Settings.
public enum KaiwaEngine: String, CaseIterable, Codable, Sendable {
    case automatic, appleIntelligence, gemini, rules

    public var label: String {
        switch self {
        case .automatic: "Automatic"
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
