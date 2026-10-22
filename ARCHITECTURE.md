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

## Quiz core

- `QuizQuestion` is the only thing views render. `choices` holds exactly 4 distinct strings (including `correctChoice`) when `.choice` is supported, else is empty. `acceptedAnswers` always contains `correctChoice`.
- `QuestionFactory` (one per `DrillKind`) creates questions and rebuilds one from an `ItemKey`; `QuestionFactoryRegistry` dispatches on the key prefix.
- `DistractorPicker.pick` walks priority tiers, shuffling inside a tier with the injected RNG (`SeededRandomNumberGenerator` for tests).
- `TypingValidator`: NFKC, trim, drop trailing `。.!?`, strip spaces, katakana→hiragana (keeps `ー`), lowercase.
- `QuizSessionViewModel` records each question exactly once through `ProgressRepository.record`; `activeMode` falls back to the mode the question supports. `QuizView` (app target) renders it: segmented mode picker, stimulus card (~42% of height), answer area (4 option cards or a pinned text field), feedback banner, summary with "Retry wrong".
- `ReviewState` / `SRSScheduler` (Leitner boxes 0…5, intervals 0/1/2/4/8/16 days) and `InMemoryProgressRepository` live in Core.

## ItemKey formats

`verb:{wordId}:{form}`, `infl:{wordId}:{cellRaw}`, `vocab:{wordId}:{m2w|w2m}`, `kanji:{rowId}:{r|w}`, `pitch:{wordId}`, `pattern:{patternId}`, `register:{wordId}:{tense}-{polarity}:{p2n|n2p}`, `dict:{wordId}`, `sent:{patternId}`.

## Persistence

SwiftData in the app target only: `ReviewRecord` (unique `key`, SRS fields), `AttemptRecord` (one row per answer), `CanDoRecord`. `SwiftDataProgressRepository` implements `ProgressRepository` using `SRSScheduler`; it **retains the `ModelContainer`** (a `ModelContext` does not, and a released container crashes the first fetch). `UserDefaultsSettingsStore` implements `SettingsStore` (scope as JSON, input mode, exam date, daily goal). `AppEnvironment.live()` builds both; `AppEnvironment.preview()` uses the in-memory implementations. `ReviewViewModel` lists due (dueDate ≤ now) and weak (`box ≤ 1 && wrongCount > 0`, or bookmarked) keys and rebuilds questions through `QuestionFactoryRegistry`.

## Drills

A drill = one `QuestionFactory` + one `DrillKind` + a key prefix. Registered factories appear in `PracticeViewModel.sections` automatically (grouped by `DrillKind.pillar`) and in `QuestionFactoryRegistry.question(for:seed:)` (used by Review).

Adding a drill:
1. Add a case to `DrillKind` (raw value = `-ui-route drill.<raw>`), its `pillar` and `title`; add the key builder to `ItemKey` and its prefix to `ItemKey.drill`.
2. Implement `makeQuestions(count:scope:seed:rng:)` and `question(for:seed:)`; the latter rebuilds with `FactorySupport.stableRNG(key)` so a key always yields the same question. Distractors come from `DistractorPicker` tiers (most plausible first).
3. Append the factory to `QuestionFactoryRegistry.all`.
4. Tests: use `FactoryTestSupport.expectWellFormed` / `expectRoundTrip` (4 distinct choices containing the answer, accepted ⊇ answer, key round trip, scope respected).

Katsuyou drills: `VerbFormQuestionFactory` (`verb:{id}:{form}`; `dictionary` is the reverse question showing the masu form; distractors: other forms of the lexeme → wrong-group conjugations → same form of other verbs) and `InflectionQuestionFactory` (`infl:{id}:{cell}`; pool excludes entries with `～`, digits, Latin or punctuation; distractors: other cells → plain↔polite swaps on same-kind lexemes → same cell on same-kind lexemes). `ConjugationReference` builds the reference tables from the engines.

Goi drills: `VocabQuestionFactory` (`vocab:{id}:{m2w|w2m}`; `m2w` accepts headword, reading and alternates and supports typing, `w2m` is choice-only; distractors never share the answer's headword or meaning; tiers same pos+level → same pos → any), `KanjiQuestionFactory` (`kanji:{row}:{r|w}`; `～` affix markers are stripped; writing distractors exclude homophones and words containing the target kanji), `PitchQuestionFactory` (`pitch:{id}`; pool = words whose pitch string parses with ≥ 2 morae; four fixed option labels; typing accepts the drop-mora number, `0` = flat; the accent is hidden in the stimulus and drawn in the feedback banner).

Bunpou drills: `PatternQuestionFactory` (`pattern:{id}`; choice-only; the example sentence is the prompt, distractor pattern texts come from the same level first and never equal the answer's text) and `RegisterShiftQuestionFactory` (`register:{id}:{tense}-{polarity}:{p2n|n2p}`; shows one register and asks for the other with the same tense/polarity; typing accepted).

## Choukai and audio

- `DictationQuestionFactory` (`dict:{id}`): TTS speaks the **reading** (avoids homograph errors); the answer is the headword (reading and alternates also accepted); homophones are never distractors. `SentenceListeningFactory` (`sent:{patternId}`): TTS speaks the example, choose among 4 written sentences.
- `SpeechService` (app) picks the best installed ja-JP voice (premium > enhanced > default). Without one, `SpeechPlaying.hasVoice` is false and the quiz card shows "Install a Japanese voice in Settings > Accessibility > Spoken Content".
- `AudioCatalog.parse` turns `Z_[LL-TT]_<kiku|hanasu|katachi|kotoba|kaiwa><suffix>.mp3` into `AudioTrack`s (lesson, sequence, kind, label). Labels repeat inside a lesson (several `Listen 1`), so rows show the track number. Only 初級2 has audio.
- `AudioLibraryViewModel` drives an `AudioPlaying` (`AudioPlayerService`, `AVAudioPlayer` with `enableRate`; rates 0.75/1/1.25). The synchronized Xcode group flattens `Kachiiro/Audio/*.mp3` into the bundle root (verified in the built `.app`), so `BundleAudioIndex` looks up files without a subdirectory.
- Playback proof: `AudioPlayerService.load` logs `load ok <fileName>` (subsystem `com.muhammadfawwaz.Kachiiro`); DEBUG launch argument `-ui-autoplay <fileName>` starts a track on the Audio library screen.
