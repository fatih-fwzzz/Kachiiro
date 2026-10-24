import Foundation
import Observation

@MainActor
@Observable
public final class VoiceInputModel {
    public enum State: Equatable {
        case idle, listening, denied, failed(String)
    }

    public static let deniedMessage = "Microphone or speech recognition access is off. Turn it on in Settings › Kachiiro, or type your answer."

    public private(set) var state: State = .idle
    public private(set) var transcript = ""

    @ObservationIgnored private let recognizer: SpeechRecognizing
    @ObservationIgnored private var accessGranted: Bool?

    public init(recognizer: SpeechRecognizing) { self.recognizer = recognizer }

    public var isListening: Bool { state == .listening }

    /// `true` before iOS has ever asked for microphone access, so the app can explain why first.
    public var needsPermissionPrimer: Bool { accessGranted == nil && recognizer.accessStatus == .notDetermined }

    public func start() async {
        guard state != .listening, accessGranted != false else { return }
        if accessGranted == nil {
            let granted = await recognizer.requestAccess()
            accessGranted = granted
            guard granted else {
                state = .denied
                return
            }
        }
        guard state != .listening else { return }
        transcript = ""
        do {
            try recognizer.start { [weak self] text in self?.transcript = text }
            state = .listening
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Stops listening and returns the last transcript.
    @discardableResult
    public func stop() -> String {
        recognizer.stop()
        if state == .listening { state = .idle }
        return transcript
    }

    public func cancel() {
        recognizer.stop()
        transcript = ""
        if state != .denied { state = .idle }
    }
}
