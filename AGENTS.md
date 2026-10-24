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
- Engine choice is automatic: Apple Intelligence when the device has it, else Gemini, else offline rules (`KaiwaAIResolver.activeEngine`). The Gemini key ships in the git-ignored `Kachiiro/Secrets.plist` (`GeminiAPIKey`); Settings no longer asks for one. iPhone 15 (A16) has no Apple Intelligence, so it uses Gemini.
- Engines are chosen per task (`AITask`): Apple Intelligence may serve only `.shadowing` and `.conversation` (free talk); `.questions` (keigo, uchi/soto) and `.checking` (judging, roleplay review, all roleplay modes) always use Gemini, else offline rules. The on-device model writes and grades keigo poorly. Readings never come from a model (`JapaneseReading`: tokenizer + course words + overrides).

## LaunchRoute smoke technique
Simulator taps cannot be scripted, so screens are reached with launch arguments: `-ui-route <route>` (dashboard, setup, practice, mock, review, `drill.<DrillKind raw>`, audio, cando, settings, `kaiwa.roleplay`, `kaiwa.roleplay.<scenarioId>`, `kaiwa.shadowing`) and `-ui-mode <choice|typing>`. Launch with RUN, wait ~3 s, screenshot, then read the PNG. New screens register their route in `LaunchRoute` and `RootView`.
- Core files that touch Core members in the app need `import KachiiroCore` (`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is on).

## ItemKey formats
`verb:{wordId}:{VerbForm}`, `infl:{wordId}:{cellRaw}`, `vocab:{wordId}:{m2w|w2m}`, `kanji:{rowId}:{r|w}`, `pitch:{wordId}`, `pattern:{patternId}`, `register:{wordId}:{tense}-{polarity}:{p2n|n2p}`, `dict:{wordId}`, `sent:{patternId}`, `keigo:v:{verbId}:{son|ken|tei}`, `keigo:s:{sentenceId}`, `uchi:{id}`. Keys are persisted: never change a format without a migration. `ai:{drill}:{uuid}` keys belong to AI-generated questions: they are never persisted and cannot be rebuilt by the registry.

## Debug launch arguments (DEBUG builds)
`-ui-debug-wrong <ItemKey>` / `-ui-debug-right <ItemKey>` record one answer at launch, for persistence smoke tests: launch once with the flag, relaunch without it, `-ui-route review` must list the key. Taps cannot be scripted in the simulator.
`-ui-autoanswer <text>` submits `<text>` (typed or as the chosen option) for the first question of a quiz so the feedback banner can be screenshotted.
`-ui-autofinish` (with a `drill.<kind>` route) answers every choice question, every third one wrongly, so the session summary can be screenshotted.
`-ui-autoplay <fileName>` (with `-ui-route audio`) plays a bundled track; check `xcrun simctl spawn <sim> log show --last 1m --predicate 'subsystem == "com.muhammadfawwaz.Kachiiro"'` for `load ok <fileName>`.
`-ui-autostart start|submit` (with `-ui-route mock`) starts the mock exam, optionally submitting it unanswered, to screenshot the exam and result screens.
`-ui-listen` (with `-ui-route drill.keigo`) starts the microphone so the permission alerts can be screenshotted; reset them with `xcrun simctl privacy <sim> reset all com.muhammadfawwaz.Kachiiro`. Real recognition accuracy needs a device.
`-ui-kaiwa-engine automatic|appleIntelligence|gemini|rules`, `-ui-kaiwa-content bundled|generated` and `-ui-gemini-key <key>` set the Kaiwa AI settings (persisted in UserDefaults/Keychain: relaunch with `automatic`/`bundled` to undo; `rules` forces offline). The iOS 26 simulators have Apple Intelligence switched off in their Settings app, so they fall back to Gemini. `-ui-autoanswer` also drives the roleplay and shadowing screens.
- SwiftData: keep the `ModelContainer` alive for as long as its `ModelContext` is used.

## Kaiwa content and AI
Keigo content (`keigo.json`, `roleplay.json`) is hand-authored in `KachiiroCore/Sources/KachiiroCore/Resources` and loaded through `Bundle.module`; `KeigoTests`/`RoleplayTests` validate it. `KaiwaAIResolver` falls back to offline rules (with a notice) when the selected engine is unavailable. FoundationModels is weak-linked (`OTHER_LDFLAGS`) so iOS 18 devices launch.

## Gemini Live roleplay
With Engine = Gemini and Content = AI-generated, roleplay is a hands-free voice call over `GeminiLiveClient` (`gemini-3.8-live`, one persistent WebSocket). `LiveVoiceEngine` captures the microphone (voice processing for echo cancellation, 16 kHz PCM up) and plays the partner (24 kHz PCM down) on one `AVAudioEngine`; the audio session is configured once per call, off the main thread. Gemini transcribes the learner (`inputTranscription`) and the partner (`outputTranscription`); `RoleplayViewModel` shows both as drafts and commits them as lines when the partner's turn completes, so a pause never splits the learner's sentence. `serverContent.interrupted` (barge-in) flushes playback. Server VAD uses `silenceDurationMs` 1200 with low end-of-speech sensitivity (`GeminiLiveClient.silenceDurationMs`); the Live docs say native-audio models do not accept `speechConfig.languageCode`. Learner lines are reviewed on `generateContent` (`reviewRoleplayLine`; `GeminiClient.models` tries `gemini-3.1-flash-lite` first). Live cannot return structured output, so a failed review leaves the line unreviewed. The simulator cannot play or record real audio; check barge-in, echo and pauses on a device.
Enabling voice processing reconfigures the audio I/O, so `AVAudioEngine` stops itself right after `start()` and posts `AVAudioEngineConfigurationChange`; `LiveVoiceEngine` rebuilds the graph and restarts on that notification. Without the restart the call is silent both ways (no mic chunks, `play` drops audio). Live roleplay needs Settings → Content = AI-generated; with bundled content, Gemini only judges the scripted roleplay. A `1011` close ("exceeded your current quota") is the key's Live quota.
Device smoke (iPhone 15 `00008120-001A75020AC3601E`): build with `-destination 'id=<udid>' -allowProvisioningUpdates`, `xcrun devicectl device install app --device <udid> build/Build/Products/Debug-iphoneos/Kachiiro.app`, `xcrun devicectl device process launch --device <udid> --terminate-existing [--console] com.muhammadfawwaz.Kachiiro -- -ui-route <route>` (app arguments after `--`; `--console` shows `print`), `xcrun devicectl device capture screenshot --device <udid> --destination /tmp/x.png`. `say -v Kyoko "…"` on the Mac speaks Japanese into the phone's microphone.
