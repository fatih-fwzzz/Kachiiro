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

## Seed data (ETL)

`scripts/build_seed.py` reads `wordlist_all.xlsx`, `sentence_patterns_list.xlsx`, `kanji_list.xlsx` and writes `Kachiiro/Resources/irodori_seed.json` (3797 words, 259 patterns with an example sentence, 659 kanji rows). Word `id` is the sheet's `「ことばリスト」順` column (not a row index). Cleaning order for headword/reading/pitch:

1. `（する）` on `N/V［3］` rows becomes `する`.
2. Parenthesised notes are extracted (nesting-aware) into `contextNote` and removed with their leading spaces; `（な）` is dropped.
3. Verbs and adjectives keep only the part before `／` (A1 verbs are `dictionary／masu`); every other pos keeps the first part and the rest goes to `alternates`.

Blank/NaN pos maps to `Other`. The script asserts the counts above.
