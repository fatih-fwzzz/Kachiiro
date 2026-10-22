# AGENTS.md

## Commands
- TEST: `cd KachiiroCore && swift test`
- BUILD: `xcodebuild -project Kachiiro.xcodeproj -scheme Kachiiro -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -derivedDataPath build build` (the simulator name alone is ambiguous: two iOS 18.x runtimes are installed)
- RUN (iPhone 16, iOS 18.5 id `7B8A05A0-1F9A-4548-9EFF-061AE0B26A17`; iPad Pro 13-inch (M4) iOS 18.5 id `C97B21DF-DE10-4B7C-90DB-816F03623D70`): `SIM=<id>; xcrun simctl boot $SIM || true; xcrun simctl install $SIM build/Build/Products/Debug-iphonesimulator/Kachiiro.app; xcrun simctl launch $SIM com.muhammadfawwaz.Kachiiro -ui-route <route>; sleep 3; xcrun simctl io $SIM screenshot /tmp/<name>.png`

## Layer rules
- View → ViewModel → (protocol) Service → Model. UI never touches data or engines.
- `KachiiroCore` imports Foundation + Observation only. No UIKit/SwiftUI/SwiftData/AVFoundation.
- Core public types are `public` `Sendable` value types; ViewModels are `@MainActor @Observable public final class`.
- The app target is `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_VERSION = 5.0`.

## Branch workflow
One branch per feature: `git checkout main && git checkout -b feature/<name>`; keep TEST and BUILD green; commit with imperative messages; merge with `git merge --no-ff feature/<name> -m "Merge feature/<name>"`; do not delete branches; **do not push** (public remote, the owner pushes).

## Data
- Regenerate seed: `python3 scripts/build_seed.py --src ~/Downloads --out Kachiiro/Resources/irodori_seed.json` (expects 3797 words / 259 patterns / 659 kanji).
- NEVER commit audio (`*.mp3`), `*.xlsx` or `*.pdf`.

## Conventions
- Tests use Swift Testing (`import Testing`).
- Drills: one `QuestionFactory` per `DrillKind`, registered in `QuestionFactoryRegistry`; stable `ItemKey` per question.
- Pitch strings use `↓` (drop), trailing `○` (flat), `／` (alternatives).

## Gemini facts for plan 2
- `gemini-2.5-flash` retires 2026-10-20; docs currently list `gemini-3.8-flash`.
- REST structured output: `generationConfig.responseFormat.text{mimeType,schema}`.
- No on-device provider (iPhone 15 / A16 lacks Apple Intelligence). Gemini is the only provider. API key goes in Settings → Keychain.

## LaunchRoute smoke technique
Simulator taps cannot be scripted, so screens are reached with launch arguments: `-ui-route <route>` (dashboard, practice, mock, review, `drill.<DrillKind raw>`, audio, cando, settings) and `-ui-mode <choice|typing>`. Launch with RUN, wait ~3 s, screenshot, then read the PNG. New screens register their route in `LaunchRoute` and `RootView`.
- Core files that touch Core members in the app need `import KachiiroCore` (`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is on).

## ItemKey formats
`verb:{wordId}:{VerbForm}`, `infl:{wordId}:{cellRaw}`, `vocab:{wordId}:{m2w|w2m}`, `kanji:{rowId}:{r|w}`, `pitch:{wordId}`, `pattern:{patternId}`, `register:{wordId}:{tense}-{polarity}:{p2n|n2p}`, `dict:{wordId}`, `sent:{patternId}`. Keys are persisted: never change a format without a migration.

## Debug launch arguments (DEBUG builds)
`-ui-debug-wrong <ItemKey>` / `-ui-debug-right <ItemKey>` record one answer at launch, for persistence smoke tests: launch once with the flag, relaunch without it, `-ui-route review` must list the key. Taps cannot be scripted in the simulator.
- SwiftData: keep the `ModelContainer` alive for as long as its `ModelContext` is used.
