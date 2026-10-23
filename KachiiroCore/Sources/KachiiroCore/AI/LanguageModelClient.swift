import Foundation

public protocol LanguageModelClient: Sendable {
    /// Returns UTF-8 JSON that matches `schema`.
    func generateJSON(system: String, prompt: String, schema: JSONSchema) async throws -> Data
}

public enum KaiwaAIError: Error, Equatable, LocalizedError {
    case invalidResponse
    case http(status: Int, message: String)
    case noValidItems
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "The AI returned an unexpected response."
        case .http(let status, let message): "Gemini error \(status): \(message)"
        case .noValidItems: "The AI did not return usable items."
        case .unavailable(let reason): reason
        }
    }
}

public enum EngineAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
}
