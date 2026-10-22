import Testing
@testable import KachiiroCore

@Suite struct GoiFactoryTests {
    let seed = TestSeed.shared

    func fixtureSeed() -> SeedData {
        let words = [
            Word(id: 1, headword: "洗う", reading: "あらう", pitch: "あらう○", meaning: "to wash", pos: .verb1, level: .a21, lesson: 3),
            Word(id: 2, headword: "愛機道", reading: "あいきどう", pitch: "あいき↓どう", meaning: "aikido", pos: .noun, level: .a21, lesson: 3),
            Word(id: 3, headword: "雨", reading: "あめ", pitch: "あ↓め", meaning: "rain", pos: .noun, level: .a21, lesson: 3),
            Word(id: 4, headword: "頭", reading: "あたま", pitch: "あたま↓", meaning: "head", pos: .noun, level: .a1, lesson: 4),
            Word(id: 5, headword: "壇水", reading: "だんすいする", pitch: "だんすい○", meaning: "mismatch", pos: .verb3, level: .a1, lesson: 4),
            Word(id: 6, headword: "海", reading: "うみ", pitch: "うみ○", meaning: "sea", pos: .noun, level: .a1, lesson: 4),
        ]
        return SeedData(words: words, patterns: [], kanji: [])
    }

    @Test func vocabWellFormedAndRoundTrips() {
        let f = VocabQuestionFactory()
        for s in UInt64(1)...5 {
            var rng = SeededRandomNumberGenerator(seed: s)
            let qs = f.makeQuestions(count: 20, scope: .all, seed: seed, rng: &rng)
            #expect(qs.count == 20)
            FactoryTestSupport.expectWellFormed(qs, f)
            FactoryTestSupport.expectRoundTrip(qs, f, seed: seed)
        }
    }

    @Test func vocabMeaningToWordTypingAcceptsHeadwordAndReading() throws {
        let f = VocabQuestionFactory()
        let word = try #require(seed.words.first { $0.headword == "会う" })
        let q = try #require(f.question(for: .vocab(word.id, reverse: false), seed: seed))
        #expect(q.supportedModes == [.choice, .typing])
        #expect(TypingValidator.isCorrect("会う", accepted: q.acceptedAnswers))
        #expect(TypingValidator.isCorrect("あう", accepted: q.acceptedAnswers))
        #expect(q.promptBody == word.meaning)
    }

    @Test func vocabWordToMeaningIsChoiceOnly() throws {
        let f = VocabQuestionFactory()
        let word = try #require(seed.words.first { $0.headword == "会う" })
        let q = try #require(f.question(for: .vocab(word.id, reverse: true), seed: seed))
        #expect(q.supportedModes == [.choice])
        #expect(q.correctChoice == word.meaning)
        #expect(q.promptBody == "会う")
        #expect(q.pitch != nil)
    }

    @Test func vocabDistractorsNeverClashWithTheAnswer() {
        let f = VocabQuestionFactory()
        var rng = SeededRandomNumberGenerator(seed: 11)
        for q in f.makeQuestions(count: 60, scope: .all, seed: seed, rng: &rng) {
            let word = seed.word(id: q.id.id!)!
            let clashing = seed.words.filter { $0.id != word.id && ($0.headword == word.headword || $0.meaning == word.meaning) }
            let wrong = Set(q.choices.filter { $0 != q.correctChoice })
            if q.id.parts[1] == "m2w" {
                #expect(wrong.isDisjoint(with: Set(clashing.map(\.headword))), "\(q.id.raw)")
            } else {
                #expect(wrong.isDisjoint(with: Set(clashing.map(\.meaning))), "\(q.id.raw)")
            }
        }
    }

    @Test func kanjiStaysInScopeAndRoundTrips() {
        let f = KanjiQuestionFactory()
        let scope = StudyScope(levels: [.a21], lessonRange: 5...10)
        for s in UInt64(1)...3 {
            var rng = SeededRandomNumberGenerator(seed: s)
            let qs = f.makeQuestions(count: 15, scope: scope, seed: seed, rng: &rng)
            #expect(qs.count == 15)
            for q in qs {
                let row = seed.kanjiEntry(id: q.id.id!)!
                #expect(row.level == .a21 && (5...10).contains(row.lesson))
            }
            FactoryTestSupport.expectWellFormed(qs, f)
            FactoryTestSupport.expectRoundTrip(qs, f, seed: seed)
        }
    }

    @Test func kanjiQuestionShapes() throws {
        let f = KanjiQuestionFactory()
        let row = try #require(seed.kanji.first)
        let r = try #require(f.question(for: .kanji(row.id, writing: false), seed: seed))
        #expect(r.promptBody == row.word && r.correctChoice == row.wordReading)
        let w = try #require(f.question(for: .kanji(row.id, writing: true), seed: seed))
        #expect(w.promptBody == row.wordReading && w.correctChoice == row.word)
        #expect(w.choices.filter { $0 != row.word }.allSatisfy { !$0.contains(row.kanji) })
    }

    @Test func pitchAnswers() throws {
        let f = PitchQuestionFactory()
        let fixture = fixtureSeed()
        let flat = try #require(f.question(for: .pitch(1), seed: fixture))
        #expect(flat.correctChoice == "平板 (heiban)")
        #expect(TypingValidator.isCorrect("0", accepted: flat.acceptedAnswers))
        let naka = try #require(f.question(for: .pitch(2), seed: fixture))
        #expect(naka.correctChoice == "中高 (nakadaka)")
        #expect(TypingValidator.isCorrect("3", accepted: naka.acceptedAnswers))
        #expect(!TypingValidator.isCorrect("2", accepted: naka.acceptedAnswers))
        let atama = try #require(f.question(for: .pitch(3), seed: fixture))
        #expect(atama.correctChoice == "頭高 (atamadaka)")
        let odaka = try #require(f.question(for: .pitch(4), seed: fixture))
        #expect(odaka.correctChoice == "尾高 (odaka)")
        #expect(Set(flat.choices) == Set(naka.choices))
        #expect(flat.choices.count == 4)
    }

    @Test func pitchNeverSelectsMoraMismatch() {
        let f = PitchQuestionFactory()
        let fixture = fixtureSeed()
        #expect(f.question(for: .pitch(5), seed: fixture) == nil)
        for s in UInt64(1)...20 {
            var rng = SeededRandomNumberGenerator(seed: s)
            let qs = f.makeQuestions(count: 20, scope: .all, seed: fixture, rng: &rng)
            #expect(qs.count == 5)
            #expect(!qs.contains { $0.id == .pitch(5) })
        }
    }

    @Test func pitchSeedWideWellFormed() {
        let f = PitchQuestionFactory()
        var rng = SeededRandomNumberGenerator(seed: 4)
        let qs = f.makeQuestions(count: 20, scope: .all, seed: seed, rng: &rng)
        #expect(qs.count == 20)
        FactoryTestSupport.expectWellFormed(qs, f)
        FactoryTestSupport.expectRoundTrip(qs, f, seed: seed)
        #expect(qs.allSatisfy { $0.pitch != nil })
    }
}

@Suite struct KanjiAffixTests {
    @Test func tildeMarkersAreNotInPromptsOrAnswers() throws {
        let seed = TestSeed.shared
        let f = KanjiQuestionFactory()
        let tilde = seed.kanji.filter { $0.word.contains("～") || $0.wordReading.contains("～") }
        #expect(!tilde.isEmpty)
        for row in tilde {
            for writing in [false, true] {
                let q = try #require(f.question(for: .kanji(row.id, writing: writing), seed: seed))
                #expect(!q.promptBody.contains("～"))
                #expect(q.choices.allSatisfy { !$0.contains("～") })
            }
        }
    }
}
