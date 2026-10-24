import Foundation

public enum LiveEvent: Equatable, Sendable {
    case setupComplete
    case audio(Data)
    /// A piece of the learner's speech, transcribed by Gemini.
    case inputTranscript(String)
    /// A piece of the partner's speech.
    case transcript(String)
    /// The learner talked over the partner: queued partner audio is stale.
    case interrupted
    case turnComplete
    case other
}

/// Gemini Live over a WebSocket: a persistent voice call. Microphone audio streams up, the partner's voice and transcripts stream down.
@MainActor
public final class GeminiLiveClient: LiveRoleplayPartner {
    public nonisolated static let model = "gemini-3.8-live"
    /// Server-side silence before the learner's turn ends; tolerates a breath mid-sentence.
    nonisolated static let silenceDurationMs = 1200
    private static let setupTimeout: Duration = .seconds(25)

    private let apiKey: String
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var receiver: Task<Void, Never>?

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
                "generationConfig": ["responseModalities": ["AUDIO"]],
                "systemInstruction": ["parts": [["text": system]]],
                "realtimeInputConfig": [
                    "automaticActivityDetection": [
                        "endOfSpeechSensitivity": "END_SENSITIVITY_LOW",
                        "silenceDurationMs": silenceDurationMs,
                    ],
                ],
                "inputAudioTranscription": ["languageCodes": ["ja-JP"]],
                "outputAudioTranscription": [String: Any](),
            ],
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    nonisolated static func turnMessage(_ turns: [(role: String, text: String)], turnComplete: Bool) -> Data {
        let body: [String: Any] = [
            "clientContent": [
                "turns": turns.map { ["role": $0.role, "parts": [["text": $0.text]]] },
                "turnComplete": turnComplete,
            ],
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    /// The opening request plus the conversation so far. The server waits for the learner when the partner spoke last.
    nonisolated static func seedMessage(history: [RoleplayViewModel.Line]) -> Data {
        var turns: [(role: String, text: String)] = [(role: "user", text: KaiwaPrompts.liveOpening)]
        turns += history.map { (role: $0.speaker == .user ? "user" : "model", text: $0.text) }
        return turnMessage(turns, turnComplete: history.last?.speaker != .partner)
    }

    nonisolated static func audioMessage(_ pcm16: Data) -> Data {
        let body: [String: Any] = [
            "realtimeInput": [
                "audio": ["data": pcm16.base64EncodedString(), "mimeType": "audio/pcm;rate=16000"],
            ],
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    /// Every event in one server frame: audio parts, learner transcript, partner transcript, interruption, turn completion.
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
        if let text = (content["inputTranscription"] as? [String: Any])?["text"] as? String {
            events.append(.inputTranscript(text))
        }
        if let text = (content["outputTranscription"] as? [String: Any])?["text"] as? String {
            events.append(.transcript(text))
        }
        if content["interrupted"] as? Bool == true { events.append(.interrupted) }
        if content["turnComplete"] as? Bool == true { events.append(.turnComplete) }
        return events.isEmpty ? [.other] : events
    }

    // MARK: Session

    public func connect(
        system: String, history: [RoleplayViewModel.Line]
    ) async throws -> AsyncThrowingStream<LiveEvent, Error> {
        close()
        let socket = session.webSocketTask(with: Self.url(apiKey: apiKey))
        task = socket
        socket.resume()
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    try await socket.send(.data(Self.setupMessage(system: system)))
                    while !Self.parse(try await Self.receive(socket)).contains(.setupComplete) {}
                }
                group.addTask {
                    try await Task.sleep(for: Self.setupTimeout)
                    await self.close()
                    throw URLError(.timedOut)
                }
                defer { group.cancelAll() }
                _ = try await group.next()
            }
            try await socket.send(.data(Self.seedMessage(history: history)))
        } catch {
            let mapped = Self.closeError(socket) ?? error
            close()
            throw mapped
        }

        let (stream, continuation) = AsyncThrowingStream<LiveEvent, Error>.makeStream()
        receiver = Task { @MainActor [weak self] in
            do {
                while true {
                    for event in Self.parse(try await Self.receive(socket)) {
                        switch event {
                        case .other, .setupComplete: break
                        default: continuation.yield(event)
                        }
                    }
                }
            } catch {
                if Task.isCancelled || self?.task !== socket {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: Self.closeError(socket) ?? error)
                }
            }
        }
        return stream
    }

    public func sendAudio(_ pcm16: Data) {
        task?.send(.data(Self.audioMessage(pcm16))) { _ in }
    }

    public func sendText(_ text: String) {
        task?.send(.data(Self.turnMessage([(role: "user", text: text)], turnComplete: true))) { _ in }
    }

    public func close() {
        receiver?.cancel()
        receiver = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    /// The server's close code and reason, which are more useful than the POSIX error `receive` throws.
    private nonisolated static func closeError(_ socket: URLSessionWebSocketTask) -> LiveSessionError? {
        guard socket.closeCode != .invalid else { return nil }
        return .closed(
            code: socket.closeCode.rawValue,
            reason: socket.closeReason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        )
    }

    private nonisolated static func receive(_ socket: URLSessionWebSocketTask) async throws -> Data {
        switch try await socket.receive() {
        case .data(let data): data
        case .string(let string): Data(string.utf8)
        @unknown default: Data()
        }
    }
}
