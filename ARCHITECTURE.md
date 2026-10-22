# Architecture

MVVM with a pure Swift package for everything testable.

Dependency direction: **View → ViewModel → (protocol) Service → Model**. Views never touch data or engines directly. Only the app target imports SwiftUI, SwiftData, AVFoundation, PencilKit and Security.

```
KachiiroCore/                     local Swift package, Foundation + Observation only
  Sources/KachiiroCore/
    Models/        Pillar, Level, Word, GrammarPattern, KanjiEntry, SeedData, CanDo, AudioTrack, ItemKey, StudyScope, PitchPattern
    Katsuyou/      Lexeme, VerbForm, KatsuyouEngine, InflectionCell, InflectionEngine, Conjugation
    Quiz/          InputMode, QuizQuestion, TypingValidator, DistractorPicker, QuestionFactory(+ one per drill), QuestionFactoryRegistry
    SRS/           ReviewState, SRSScheduler
    Services/      protocols (ProgressRepository, SettingsStore, SpeechPlaying, AudioPlaying) + in-memory implementations
    ViewModels/    @MainActor @Observable classes
  Tests/KachiiroCoreTests/   Swift Testing
Kachiiro/                         app target (PBXFileSystemSynchronizedRootGroup)
  App/           KachiiroApp, RootView, LaunchRoute, AppEnvironment (composition root)
  DesignSystem/  AppTheme, AppleBadge, PitchAccentView, QuizCardStyle
  Persistence/   SwiftData models, SwiftDataProgressRepository, UserDefaultsSettingsStore
  Platform/      SpeechService, AudioPlayerService, BundleAudioIndex
  Features/      SwiftUI views per pillar / screen
  Resources/     irodori_seed.json, cando.json
  Audio/         *.mp3 (gitignored)
scripts/build_seed.py             xlsx → irodori_seed.json
```

The package is linked into the app as a local Swift package (`XCLocalSwiftPackageReference` in `project.pbxproj`). Package language mode is Swift 5 to match the app target.

Contracts, persistence, ETL, testing and "adding a drill" sections are extended by the branches that introduce them.
