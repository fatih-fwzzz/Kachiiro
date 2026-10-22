import Testing
@testable import KachiiroCore

@Suite struct BunpouFactoryTests {
    let seed = TestSeed.shared

    @Test func patternWellFormedAndRoundTrips() {
        let f = PatternQuestionFactory()
        for s in UInt64(1)...5 {
            var rng = SeededRandomNumberGenerator(seed: s)
            let qs = f.makeQuestions(count: 20, scope: .all, seed: seed, rng: &rng)
            #expect(qs.count == 20)
            FactoryTestSupport.expectWellFormed(qs, f)
            FactoryTestSupport.expectRoundTrip(qs, f, seed: seed)
            for q in qs { #expect(q.supportedModes == [.choice]) }
        }
    }

    @Test func patternChoicesHaveNoDuplicateTextAndPreferSameLevel() throws {
        let f = PatternQuestionFactory()
        let level = Level.a22
        let scope = StudyScope(levels: [level], lessonRange: nil)
        var rng = SeededRandomNumberGenerator(seed: 2)
        for q in f.makeQuestions(count: 30, scope: scope, seed: seed, rng: &rng) {
            #expect(Set(q.choices).count == 4)
            let pattern = try #require(seed.pattern(id: q.id.id!))
            #expect(q.correctChoice == pattern.pattern)
            #expect(q.promptBody == pattern.example)
            let sameLevel = Set(seed.patterns.filter { $0.level == level && $0.pattern != pattern.pattern }.map(\.pattern))
            #expect(q.choices.filter { $0 != q.correctChoice }.allSatisfy(sameLevel.contains))
        }
    }

    @Test func patternScopeFiltering() {
        let scope = StudyScope(levels: [.a1], lessonRange: 3...5)
        var rng = SeededRandomNumberGenerator(seed: 5)
        let qs = PatternQuestionFactory().makeQuestions(count: 20, scope: scope, seed: seed, rng: &rng)
        #expect(!qs.isEmpty)
        for q in qs {
            let p = seed.pattern(id: q.id.id!)!
            #expect(p.level == .a1 && (3...5).contains(p.lesson))
        }
    }

    @Test func registerWellFormedAndRoundTrips() {
        let f = RegisterShiftQuestionFactory()
        for s in UInt64(1)...5 {
            var rng = SeededRandomNumberGenerator(seed: s)
            let qs = f.makeQuestions(count: 20, scope: .all, seed: seed, rng: &rng)
            #expect(qs.count == 20)
            FactoryTestSupport.expectWellFormed(qs, f)
            FactoryTestSupport.expectRoundTrip(qs, f, seed: seed)
        }
    }

    @Test func politeToPlainMatchesEngine() throws {
        let f = RegisterShiftQuestionFactory()
        let word = try #require(seed.words.first { $0.headword == "食べる" })
        let lexeme = try #require(Lexeme(word: word))
        let key = ItemKey.register(word.id, tense: .past, polarity: .negative, toPlain: true)
        let q = try #require(f.question(for: key, seed: seed))
        let polite = InflectionCell(politeness: .polite, tense: .past, polarity: .negative)
        let plain = InflectionCell(politeness: .plain, tense: .past, polarity: .negative)
        #expect(q.promptBody == InflectionEngine.inflect(lexeme, cell: polite).display)
        #expect(q.promptBody == "食べませんでした")
        #expect(q.correctChoice == InflectionEngine.inflect(lexeme, cell: plain).display)
        #expect(q.correctChoice == "食べなかった")
        #expect(q.supportedModes == [.choice, .typing])
    }

    @Test func plainToPoliteDirection() throws {
        let f = RegisterShiftQuestionFactory()
        let word = try #require(seed.words.first { $0.headword == "行く" })
        let key = ItemKey.register(word.id, tense: .nonPast, polarity: .affirmative, toPlain: false)
        let q = try #require(f.question(for: key, seed: seed))
        #expect(q.promptBody == "行く")
        #expect(q.correctChoice == "行きます")
        #expect(TypingValidator.isCorrect("いきます", accepted: q.acceptedAnswers))
    }

    @Test func malformedKeysReturnNil() {
        let f = RegisterShiftQuestionFactory()
        #expect(f.question(for: ItemKey("register:1:bogus:p2n"), seed: seed) == nil)
        #expect(f.question(for: ItemKey("register:1:past-negative:x"), seed: seed) == nil)
        #expect(PatternQuestionFactory().question(for: ItemKey("pattern:99999"), seed: seed) == nil)
    }
}
