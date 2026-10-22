@MainActor
public protocol SpeechPlaying: AnyObject {
    /// `false` when no Japanese voice is installed; `speak` then does nothing.
    var hasVoice: Bool { get }
    func speak(_ text: String, slow: Bool)
    func stop()
}
