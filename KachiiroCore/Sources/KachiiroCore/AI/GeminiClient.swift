import Foundation

public struct GeminiClient: LanguageModelClient {
    public static let model = "gemini-3.8-flash"

    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func makeRequest(system: String, prompt: String, schema: JSONSchema) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(Self.model):generateContent")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": [
                "responseFormat": ["text": ["mimeType": "APPLICATION_JSON", "schema": schema.jsonObject()]]
            ],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// The generated JSON text of a `generateContent` response, or `.http` for a non-2xx status.
    public static func parse(data: Data, status: Int) throws -> Data {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200..<300).contains(status) else {
            let message = (root?["error"] as? [String: Any])?["message"] as? String
            throw KaiwaAIError.http(status: status, message: message ?? "Unknown error")
        }
        guard let candidates = root?["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { throw KaiwaAIError.invalidResponse }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw KaiwaAIError.invalidResponse }
        return Data(text.utf8)
    }

    public func generateJSON(system: String, prompt: String, schema: JSONSchema) async throws -> Data {
        let (data, response) = try await session.data(for: makeRequest(system: system, prompt: prompt, schema: schema))
        guard let http = response as? HTTPURLResponse else { throw KaiwaAIError.invalidResponse }
        return try Self.parse(data: data, status: http.statusCode)
    }
}
