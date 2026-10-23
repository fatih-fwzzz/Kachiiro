import Foundation

public enum LiveEvent: Equatable, Sendable {
    case setupComplete
    case audio(Data)
    case transcript(String)
    case turnComplete
    case other
}

/// Gemini Live over a WebSocket: speaks the partner's turns as audio and reports a transcript.
@MainActor
public final class GeminiLiveClient: LiveRoleplayPartner {
    public static let model = "gemini-3.1-flash-live-preview"
    private static let timeout: Duration = .seconds(25)

    private let apiKey: String
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var sentLines = 0

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: Wire format

    nonisolated static func url(apiKey: String) -> URL {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "generativelanguage.googleapis.com"
        components.path = "/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components.url!
    }

    nonisolated static func setupMessage(system: String) -> Data {
        let body: [String: Any] = [
            "setup": [
                "model": "models/\(model)",
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "speechConfig": ["languageCode": "ja-JP"],
                ],
                "systemInstruction": ["parts": [["text": system]]],
                "outputAudioTranscription": [String: Any](),
            ],
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    nonisolated static func turnMessage(_ turns: [(role: String, text: String)]) -> Data {
        let body: [String: Any] = [
            "clientContent": [
                "turns": turns.map { ["role": $0.role, "parts": [["text": $0.text]]] },
                "turnComplete": true,
            ],
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    /// Every event in one server frame: audio parts, then the transcript piece, then turn completion.
    nonisolated static func parse(_ data: Data) -> [LiveEvent] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [.other] }
        if root["setupComplete"] != nil { return [.setupComplete] }
        guard let content = root["serverContent"] as? [String: Any] else { return [.other] }
        var events: [LiveEvent] = []
        let parts = (content["modelTurn"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
        for part in parts {
            if let inline = part["inlineData"] as? [String: Any],
               let base64 = inline["data"] as? String, let audio = Data(base64Encoded: base64) {
                events.append(.audio(audio))
            }
        }
        if let text = (content["outputTranscription"] as? [String: Any])?["text"] as? String {
            events.append(.transcript(text))
        }
        if content["turnComplete"] as? Bool == true { events.append(.turnComplete) }
        return events.isEmpty ? [.other] : events
    }

    // MARK: Session

    public func reply(
        system: String, history: [RoleplayViewModel.Line], onAudio: @escaping @MainActor (Data) -> Void
    ) async throws -> String {
        do {
            let text = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { @MainActor in
                    try await self.exchange(system: system, history: history, onAudio: onAudio)
                }
                group.addTask {
                    try await Task.sleep(for: Self.timeout)
                    await self.close()
                    throw URLError(.timedOut)
                }
                defer { group.cancelAll() }
                return try await group.next() ?? ""
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw KaiwaAIError.invalidResponse }
            return trimmed
        } catch {
            close()
            throw error
        }
    }

    public func close() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    private func exchange(
        system: String, history: [RoleplayViewModel.Line], onAudio: @MainActor (Data) -> Void
    ) async throws -> String {
        let socket = try await connectedSocket(system: system)
        var turns = history.dropFirst(sentLines).map { (role: $0.speaker == .user ? "user" : "model", text: $0.text) }
        if turns.isEmpty || turns.last?.role == "model" { turns.append((role: "user", text: KaiwaPrompts.liveOpening)) }
        try await socket.send(.data(Self.turnMessage(turns)))
        sentLines = history.count

        var transcript = ""
        while true {
            for event in Self.parse(try await Self.receive(socket)) {
                switch event {
                case .audio(let data): onAudio(data)
                case .transcript(let piece): transcript += piece
                case .turnComplete: return transcript
                case .setupComplete, .other: break
                }
            }
        }
    }

    private func connectedSocket(system: String) async throws -> URLSessionWebSocketTask {
        if let task { return task }
        let socket = session.webSocketTask(with: Self.url(apiKey: apiKey))
        task = socket
        socket.resume()
        try await socket.send(.data(Self.setupMessage(system: system)))
        while !Self.parse(try await Self.receive(socket)).contains(.setupComplete) {}
        sentLines = 0
        return socket
    }

    private static func receive(_ socket: URLSessionWebSocketTask) async throws -> Data {
        switch try await socket.receive() {
        case .data(let data): data
        case .string(let string): Data(string.utf8)
        @unknown default: Data()
        }
    }
}
