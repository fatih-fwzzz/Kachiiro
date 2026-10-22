@MainActor
public protocol SpeechPlaying: AnyObject {
    func speak(_ text: String, slow: Bool)
    func stop()
}
