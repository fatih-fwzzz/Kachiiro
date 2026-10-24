import Foundation

/// A Gemini Live voice session: the learner's microphone audio goes in, the partner's voice and transcripts come out.
@MainActor public protocol LiveRoleplayPartner: AnyObject {
    /// Opens a session seeded with `history` and returns its server events; the stream ends when the session closes.
    func connect(system: String, history: [RoleplayViewModel.Line]) async throws -> AsyncThrowingStream<LiveEvent, Error>
    /// Streams 16 kHz 16-bit little-endian mono microphone PCM.
    func sendAudio(_ pcm16: Data)
    /// Sends a typed learner line as a complete turn.
    func sendText(_ text: String)
    func close()
}

/// Full-duplex call audio: echo-cancelled microphone capture plus streamed partner playback.
@MainActor public protocol LiveAudioIO: AnyObject {
    /// Configures the call audio session and starts playback, plus capture when microphone access is granted.
    /// `onChunk` receives 16 kHz 16-bit mono PCM. Throws `LiveAudioError.microphoneDenied` after starting playback-only.
    func start(onChunk: @escaping @MainActor @Sendable (Data) -> Void) async throws
    /// Plays 24 kHz 16-bit little-endian mono PCM.
    func play(_ pcm16: Data)
    /// Drops queued partner audio (barge-in).
    func flushPlayback()
    func stop()
}

public enum LiveAudioError: Error, LocalizedError, Equatable {
    case microphoneDenied
    public var errorDescription: String? {
        "Microphone access is off. Turn it on in Settings › Kachiiro, or type your reply."
    }
}

public enum LiveSessionError: Error, LocalizedError, Equatable {
    case closed(code: Int, reason: String)
    public var errorDescription: String? {
        switch self {
        case .closed(let code, let reason):
            reason.isEmpty ? "Gemini Live closed the session (\(code))." : "Gemini Live closed the session (\(code)): \(reason)"
        }
    }
}
