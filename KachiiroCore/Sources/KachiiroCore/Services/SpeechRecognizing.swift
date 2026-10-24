import Foundation

@MainActor
public enum SpeechAccessStatus: Sendable { case notDetermined, granted, denied }

public protocol SpeechRecognizing: AnyObject {
    /// Microphone and speech-recognition access without asking.
    var accessStatus: SpeechAccessStatus { get }
    /// Asks for microphone and speech-recognition access; `true` only when both are granted.
    func requestAccess() async -> Bool
    /// Starts listening; `onTranscript` receives the full transcript so far, on the main actor.
    func start(onTranscript: @escaping @MainActor (String) -> Void) throws
    func stop()
}

public extension SpeechRecognizing {
    var accessStatus: SpeechAccessStatus { .notDetermined }
}

public enum SpeechRecognitionError: Error, LocalizedError {
    case unavailable

    public var errorDescription: String? { "Japanese speech recognition is not available right now." }
}
