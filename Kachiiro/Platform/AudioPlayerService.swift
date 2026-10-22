import AVFoundation
import OSLog
import KachiiroCore

@MainActor
final class AudioPlayerService: AudioPlaying {
    private static let log = Logger(subsystem: "com.muhammadfawwaz.Kachiiro", category: "audio")
    private var player: AVAudioPlayer?
    private var preferredRate: Float = 1.0

    var isPlaying: Bool { player?.isPlaying ?? false }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }

    var rate: Float {
        get { preferredRate }
        set {
            preferredRate = newValue
            player?.rate = newValue
        }
    }

    func load(fileName: String) throws {
        guard let url = BundleAudioIndex.url(for: fileName) else {
            Self.log.error("load failed (missing) \(fileName, privacy: .public)")
            throw CocoaError(.fileNoSuchFile)
        }
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        player?.stop()
        let next = try AVAudioPlayer(contentsOf: url)
        next.enableRate = true
        next.rate = preferredRate
        next.prepareToPlay()
        player = next
        Self.log.info("load ok \(fileName, privacy: .public)")
    }

    func play() { player?.play() }
    func pause() { player?.pause() }
    func seek(to time: TimeInterval) { player?.currentTime = time }
}
