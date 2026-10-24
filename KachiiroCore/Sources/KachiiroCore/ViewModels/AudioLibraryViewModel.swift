import Foundation
import Observation

@MainActor
@Observable
public final class AudioLibraryViewModel {
    public static let rates: [Float] = [0.75, 1.0, 1.25]
    public static let missingAudioMessage = "Copy the Irodori audio into Kachiiro/Audio (see AUDIO_README.md)"

    public let lessons: [LessonAudio]
    public private(set) var currentTrack: AudioTrack?
    public private(set) var isPlaying = false
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var rate: Float = 1.0
    public private(set) var errorMessage: String?

    private let player: AudioPlaying

    public init(fileNames: [String], player: AudioPlaying) {
        self.lessons = AudioCatalog.byLesson(AudioCatalog.parse(fileNames: fileNames))
        self.player = player
    }

    public var isEmpty: Bool { lessons.isEmpty }

    public func tracks(inLesson lesson: Int) -> [AudioTrack] {
        lessons.first { $0.lesson == lesson }?.tracks ?? []
    }

    /// Loads and starts `track`.
    public func select(_ track: AudioTrack) {
        do {
            try player.load(fileName: track.fileName)
            currentTrack = track
            errorMessage = nil
            player.rate = rate
            player.play()
        } catch {
            currentTrack = nil
            errorMessage = "Could not open \(track.fileName)"
        }
        refresh()
    }

    public func togglePlay() {
        guard currentTrack != nil else { return }
        if player.isPlaying { player.pause() } else { player.play() }
        refresh()
    }

    /// Stops playback, rewinds and closes the player.
    public func stop() {
        guard currentTrack != nil else { return }
        player.pause()
        player.seek(to: 0)
        currentTrack = nil
        refresh()
    }

    public func skip(by seconds: TimeInterval) {
        guard currentTrack != nil else { return }
        player.seek(to: min(max(0, player.currentTime + seconds), player.duration))
        refresh()
    }

    public func seek(to time: TimeInterval) {
        guard currentTrack != nil else { return }
        player.seek(to: min(max(0, time), player.duration))
        refresh()
    }

    public func setRate(_ newRate: Float) {
        rate = newRate
        player.rate = newRate
        refresh()
    }

    /// Copies the player's state; call from a timer while the screen is visible.
    public func refresh() {
        isPlaying = player.isPlaying
        currentTime = player.currentTime
        duration = player.duration
    }
}
