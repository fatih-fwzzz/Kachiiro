# Kachiiro 勝色

SwiftUI study app for iPhone and iPad. Goal: pass a six-pillar Japanese vocational-school test in seven days, using the Irodori (初級) course data, with a later path to JLPT N5 → N1.

## Offline pillars (this build)

| Pillar | What it does |
|---|---|
| Katsuyou | Verb-form drill (11 forms), plain/polite inflection matrix, reference tables |
| Goi | Vocabulary (meaning ↔ word), kanji reading/writing, pitch-accent type drill |
| Bunpou | Sentence-pattern recognition, plain ↔ polite register-shift drill |
| Choukai | TTS dictation, sentence listening, bundled lesson audio library (初級2) |
| Kaiwa | Can-do checklist tied to the lesson audio |

Plus: study scope (level + lesson range), Leitner SRS weak/due queue, 20-minute mock exam, dashboard with exam countdown and daily goal, iPad workspace (reference column, scratchpad, keyboard shortcuts).

## Status

All offline pillars, the SRS queue, mock exam, dashboard/settings and the iPad workspace are implemented (see `ARCHITECTURE.md`). Dokkai, Kaiwa roleplay, Choukai comprehension and N3–N1 are not started; they need Gemini and are covered by plan 2.

## Setup

1. Clone and open `Kachiiro.xcodeproj` (Xcode 26+, deployment target iOS 18.0).
2. Audio (optional, not committed): `cp ~/Downloads/Z_audio_all/*.mp3 Kachiiro/Audio/` — see `Kachiiro/Audio/AUDIO_README.md`.
3. Seed data (optional, `Kachiiro/Resources/irodori_seed.json` is committed): `python3 scripts/build_seed.py --src ~/Downloads --out Kachiiro/Resources/irodori_seed.json`.
4. Build: `xcodebuild -project Kachiiro.xcodeproj -scheme Kachiiro -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -derivedDataPath build build`
5. Test: `cd KachiiroCore && swift test`
6. Smoke screens without tapping: launch with `-ui-route <dashboard|practice|mock|review|drill.<kind>|audio|cando|settings>` (see `AGENTS.md`).

## Data and licensing

The Irodori course material belongs to The Japan Foundation. The source spreadsheets, PDFs and MP3 files are **not** committed. Only the derived `irodori_seed.json` and the hand-transcribed `cando.json` are in the repo.

## Roadmap (plan 2, needs Gemini)

Dokkai (reading), Kaiwa roleplay, Choukai comprehension, and N3 → N1 content. The Gemini API key will be entered in Settings and stored in the Keychain. Nothing for these pillars is stubbed in this build.
