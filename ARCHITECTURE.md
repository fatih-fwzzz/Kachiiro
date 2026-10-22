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

## Katsuyou engine

`KatsuyouEngine.conjugate(_:form:as:)` runs one algorithm on the headword and on the reading and merges the results into a `Conjugation` (`display` = written form, `accepted` = every valid string). `as:` overrides the group so drills can build wrong-group distractors. Dataset exceptions: `いく` compounds use `って/った`; `ある` compounds have `ない` as negative and no potential/passive/causative forms; `しぬ` has no causative-passive; `来る` keeps `来` plus okurigana. `InflectionEngine.inflect(_:cell:)` builds the 8-cell plain/polite matrix (`いい` → `よ…`, `かわいい` stays regular). Tests transcribe `Conjugation of Verbs.pdf` and `Plain form and Polite form.pdf`.

## Design system and shell

- `DesignSystem/AppTheme.swift`: adaptive system surfaces, monochrome Apple-blue ramp, system fonts only (`.rounded` UI, `.serif` for exam text; Hiragino is the automatic CJK fallback).
- `PitchAccentView` draws a 1.5 pt blue line over the high morae with a tick at the drop. `PitchPattern.parse(pitch:reading:)` (Core) returns `nil` when the mora counts of pitch and reading differ. Phonetic shape: flat = low first mora then high; atamadaka = only the first mora high; nakadaka/odaka = high from mora 2 up to the drop.
- `RootView`: `TabView` (`.tabViewStyle(.sidebarAdaptable)`) with Dashboard, Practice, Mock Exam, Review, each in a `NavigationStack`. iPhone shows a tab bar; iPad shows a top tab bar with a sidebar toggle.
- `AppEnvironment` is the composition root (`@Observable`), created in `KachiiroApp` and injected with `.environment`.
- `LaunchRoute` parses `-ui-route <dashboard|practice|mock|review|drill.<DrillKind>|audio|cando|settings>` and `-ui-mode <choice|typing>` from the process arguments so every screen can be reached for screenshot smoke tests.
