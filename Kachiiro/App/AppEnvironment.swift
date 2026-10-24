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
    let liveAudio: LiveAudioIO
    let voiceInput: VoiceInputModel
    let keys: APIKeyStore
    let aiResolver: KaiwaAIResolver

    init(
        seed: SeedData, repository: ProgressRepository, settings: SettingsStore,
        speech: SpeechPlaying, audioPlayer: AudioPlaying, liveAudio: LiveAudioIO,
        voiceInput: VoiceInputModel, keys: APIKeyStore
    ) {
        self.seed = seed
        self.repository = repository
        self.settings = settings
        self.speech = speech
        self.audioPlayer = audioPlayer
        self.liveAudio = liveAudio
        self.voiceInput = voiceInput
        self.keys = keys
        aiResolver = KaiwaAIResolver(
            settings: settings, keys: keys,
            appleAvailability: { AppleIntelligence.availability() },
            makeAppleClient: { AppleIntelligence.makeClient() },
            readings: JapaneseReading(words: seed.words)
        )
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
                speech: SpeechService(), audioPlayer: AudioPlayerService(), liveAudio: LiveVoiceEngine(),
                voiceInput: VoiceInputModel(recognizer: SpeechRecognitionService()), keys: KeychainAPIKeyStore()
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
            audioPlayer: AudioPlayerService(), liveAudio: LiveVoiceEngine(),
            voiceInput: VoiceInputModel(recognizer: SpeechRecognitionService()), keys: InMemoryAPIKeyStore()
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
            inputModeOverride: LaunchRoute.inputModeFromProcess(), aiResolver: aiResolver
        )
    }

    @MainActor
    func makeAudioLibraryViewModel() -> AudioLibraryViewModel {
        AudioLibraryViewModel(fileNames: BundleAudioIndex.fileNames(), player: audioPlayer)
    }

    @MainActor
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(settings: settings, repository: repository)
    }

    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(store: settings, repository: repository, aiResolver: aiResolver)
    }

    @MainActor
    func makeMockExamViewModel() -> MockExamViewModel {
        MockExamViewModel(seed: seed, settings: settings, repository: repository, speech: speech)
    }

    @MainActor
    func makeRoleplayViewModel(_ scenario: RoleplayScenario) -> RoleplayViewModel {
        let mode: RoleplayViewModel.Mode
        // Every roleplay mode grades the learner's lines, so it uses the checking engine (Gemini).
        if let partner = aiResolver.liveRoleplayPartner(), let reviewer = aiResolver.service(for: .checking) {
            mode = .live(partner: partner, reviewer: reviewer, audio: liveAudio)
        } else if aiResolver.usesGeneratedContent(for: .checking), let service = aiResolver.service(for: .checking) {
            mode = .free(service)
        } else {
            mode = .scripted(judge: aiResolver.service(for: .checking))
        }
        return RoleplayViewModel(scenario: scenario, mode: mode, speech: speech)
    }

    @MainActor
    func makeShadowingViewModel() -> ShadowingViewModel {
        ShadowingViewModel(
            lines: ShadowingLine.bundledLines(seed: seed), speech: speech,
            generator: aiResolver.usesGeneratedContent(for: .shadowing) ? aiResolver.service(for: .shadowing) : nil
        )
    }

    @MainActor
    func makeCanDoViewModel() -> CanDoViewModel {
        let canDos: [CanDo]
        if let url = Bundle.main.url(forResource: "cando", withExtension: "json"),
           let data = try? Data(contentsOf: url), let decoded = try? CanDo.load(from: data) {
            canDos = decoded
        } else {
            canDos = []
        }
        return CanDoViewModel(canDos: canDos, repository: repository, audioFileNames: BundleAudioIndex.fileNames())
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
        if let engine = Self.value(after: "-ui-kaiwa-engine", in: args).flatMap(KaiwaEngine.init(rawValue:)) {
            settings.kaiwaEngine = engine
        }
        if let content = Self.value(after: "-ui-kaiwa-content", in: args).flatMap(KaiwaContentSource.init(rawValue:)) {
            settings.kaiwaContent = content
        }
        if let key = Self.value(after: "-ui-gemini-key", in: args) { keys.setGeminiKey(key) }
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }
    #endif
}
