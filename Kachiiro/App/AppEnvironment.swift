import Foundation
import Observation
import SwiftData
import KachiiroCore

/// Composition root: owns the long-lived dependencies and builds view models for the views.
@Observable
final class AppEnvironment {
    let seed: SeedData
    let repository: ProgressRepository
    let settings: SettingsStore
    let speech: SpeechPlaying
    let audioPlayer: AudioPlaying

    init(
        seed: SeedData, repository: ProgressRepository, settings: SettingsStore,
        speech: SpeechPlaying, audioPlayer: AudioPlaying
    ) {
        self.seed = seed
        self.repository = repository
        self.settings = settings
        self.speech = speech
        self.audioPlayer = audioPlayer
    }

    @MainActor
    static func live() -> AppEnvironment {
        guard let url = Bundle.main.url(forResource: "irodori_seed", withExtension: "json") else {
            fatalError("irodori_seed.json missing from the app bundle")
        }
        do {
            let seed = try SeedData.load(from: Data(contentsOf: url))
            let container = try SwiftDataProgressRepository.makeContainer()
            let repository = SwiftDataProgressRepository(container: container)
            let env = AppEnvironment(
                seed: seed, repository: repository, settings: UserDefaultsSettingsStore(),
                speech: SpeechService(), audioPlayer: AudioPlayerService()
            )
            #if DEBUG
            env.applyDebugLaunchArguments()
            #endif
            return env
        } catch {
            fatalError("App environment could not be created: \(error)")
        }
    }

    @MainActor
    static func preview() -> AppEnvironment {
        AppEnvironment(
            seed: SeedData(words: [], patterns: [], kanji: []),
            repository: InMemoryProgressRepository(),
            settings: InMemorySettingsStore(),
            speech: SpeechService(),
            audioPlayer: AudioPlayerService()
        )
    }

    // MARK: View model factories

    @MainActor
    func makeReviewViewModel() -> ReviewViewModel {
        ReviewViewModel(repository: repository, seed: seed, settings: settings, speech: speech)
    }

    @MainActor
    func makePracticeViewModel() -> PracticeViewModel {
        PracticeViewModel(
            seed: seed, settings: settings, repository: repository, speech: speech,
            inputModeOverride: LaunchRoute.inputModeFromProcess()
        )
    }

    @MainActor
    func makeAudioLibraryViewModel() -> AudioLibraryViewModel {
        AudioLibraryViewModel(fileNames: BundleAudioIndex.fileNames(), player: audioPlayer)
    }

    #if DEBUG
    /// `-ui-debug-wrong <ItemKey>` / `-ui-debug-right <ItemKey>` record one answer at launch (persistence smoke tests).
    @MainActor
    private func applyDebugLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        for (flag, correct) in [("-ui-debug-wrong", false), ("-ui-debug-right", true)] {
            guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { continue }
            let key = ItemKey(args[i + 1])
            repository.record(key, pillar: key.drill?.pillar ?? .goi, correct: correct, mode: .choice, at: .now)
        }
    }
    #endif
}
