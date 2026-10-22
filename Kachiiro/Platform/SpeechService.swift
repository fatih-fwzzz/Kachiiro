import AVFoundation
import KachiiroCore

/// Text-to-speech through the best installed ja-JP voice (premium > enhanced > default).
@MainActor
final class SpeechService: SpeechPlaying {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice? = {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ja-JP" }
            .max { $0.quality.rawValue < $1.quality.rawValue }
    }()

    var hasVoice: Bool { voice != nil }

    func speak(_ text: String, slow: Bool) {
        guard let voice else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = slow ? AVSpeechUtteranceDefaultSpeechRate * 0.8 : AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
