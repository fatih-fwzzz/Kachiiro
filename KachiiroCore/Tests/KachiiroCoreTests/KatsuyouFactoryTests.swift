import Foundation
import Testing
@testable import KachiiroCore

@Suite struct KatsuyouFactoryTests {
    let seed = TestSeed.shared

    @Test func verbFormsProducesExactCountWellFormed() {
        let f = VerbFormQuestionFactory()
        for s in UInt64(1)...5 {
            var rng = SeededRandomNumberGenerator(seed: s)
            let qs = f.makeQuestions(count: 20, scope: .all, seed: seed, rng: &rng)
            #expect(qs.count == 20)
            FactoryTestSupport.expectWellFormed(qs, f)
            FactoryTestSupport.expectRoundTrip(qs, f, seed: seed)
        }
    }

    @Test func verbFormsPromptAndAnswerMatchEngine() throws {
        let f = VerbFormQuestionFactory()
        let word = try #require(seed.words.first { $0.headword == "食べる" })
        let q = try #require(f.question(for: .verb(word.id, .causativePassive), seed: seed))
        #expect(q.promptBody == "食べる")
        #expect(q.promptReading == "たべる")
        #expect(q.correctChoice == "食べさせられる")
        #expect(q.acceptedAnswers.contains("たべさせられる"))
        #expect(q.promptTitle.contains("使役受身"))
    }

    @Test func reverseDictionaryQuestionShowsMasuForm() throws {
        let f = VerbFormQuestionFactory()
        let word = try #require(seed.words.first { $0.headword == "食べる" })
        let q = try #require(f.question(for: .verb(word.id, .dictionary), seed: seed))
        #expect(q.promptBody == "食べます")
        #expect(q.correctChoice == "食べる")
    }

    @Test func verbDistractorsIncludeWrongGroupFormsWhenAvailable() throws {
        let f = VerbFormQuestionFactory()
        let word = try #require(seed.words.first { $0.headword == "書く" })
        let q = try #require(f.question(for: .verb(word.id, .te), seed: seed))
        #expect(q.correctChoice == "書いて")
        #expect(q.choices.count == 4)
    }

    @Test func verbSessionStaysInsideScope() {
        let f = VerbFormQuestionFactory()
        let scope = StudyScope(levels: [.a21], lessonRange: 3...4)
        var rng = SeededRandomNumberGenerator(seed: 9)
        let qs = f.makeQuestions(count: 10, scope: scope, seed: seed, rng: &rng)
        #expect(qs.count == 10)
        for q in qs {
            let word = seed.word(id: q.id.id!)!
            #expect(scope.contains(level: word.level, lesson: word.lesson))
        }
    }

    @Test func emptyScopeReturnsNoQuestions() {
        let scope = StudyScope(levels: [.a1], lessonRange: 1...2)
        var rng = SeededRandomNumberGenerator(seed: 1)
        #expect(VerbFormQuestionFactory().makeQuestions(count: 20, scope: scope, seed: seed, rng: &rng).isEmpty)
    }

    @Test func inflectionProducesExactCountWellFormed() {
        let f = InflectionQuestionFactory()
        for s in UInt64(1)...5 {
            var rng = SeededRandomNumberGenerator(seed: s)
            let qs = f.makeQuestions(count: 20, scope: .all, seed: seed, rng: &rng)
            #expect(qs.count == 20)
            FactoryTestSupport.expectWellFormed(qs, f)
            FactoryTestSupport.expectRoundTrip(qs, f, seed: seed)
        }
    }

    @Test func inflectionPoolExcludesSymbolsAndLatin() {
        let f = InflectionQuestionFactory()
        var rng = SeededRandomNumberGenerator(seed: 3)
        let qs = f.makeQuestions(count: 200, scope: .all, seed: seed, rng: &rng)
        for q in qs {
            let w = seed.word(id: q.id.id!)!
            #expect(FactorySupport.isPlainJapanese(w.headword) && FactorySupport.isPlainJapanese(w.reading))
        }
    }

    @Test func inflectionAnswerMatchesEngine() throws {
        let f = InflectionQuestionFactory()
        let word = try #require(seed.words.first { $0.headword == "かっこいい" })
        let cell = InflectionCell(politeness: .plain, tense: .past, polarity: .negative)
        let q = try #require(f.question(for: .infl(word.id, cell), seed: seed))
        #expect(q.correctChoice == "かっこよくなかった")
        #expect(q.promptTitle == "Plain · Past · Negative")
    }

    @Test func inflectionEmptyScope() {
        let scope = StudyScope(levels: [], lessonRange: nil)
        var rng = SeededRandomNumberGenerator(seed: 1)
        #expect(InflectionQuestionFactory().makeQuestions(count: 5, scope: scope, seed: seed, rng: &rng).isEmpty)
    }

    @Test func unknownOrMalformedKeysReturnNil() {
        #expect(QuestionFactoryRegistry.question(for: ItemKey("verb:999999:te"), seed: seed) == nil)
        #expect(QuestionFactoryRegistry.question(for: ItemKey("verb:1:bogus"), seed: seed) == nil)
        #expect(QuestionFactoryRegistry.question(for: ItemKey("nonsense"), seed: seed) == nil)
    }
}

@MainActor
@Suite struct PracticeAndReviewTests {
    let seed = TestSeed.shared

    @Test func practiceSessionHasTwentyQuestionsAndHonorsMode() throws {
        let settings = InMemorySettingsStore()
        settings.inputMode = .typing
        let vm = PracticeViewModel(seed: seed, settings: settings, repository: InMemoryProgressRepository())
        let session = try #require(vm.makeSession(for: .verbForms))
        #expect(session.total == 20)
        #expect(session.mode == .typing)
        #expect(vm.message == nil)
        #expect(vm.sections.first?.pillar == .katsuyou)
        #expect(vm.sections.first?.drills == [.verbForms, .inflectionMatrix])
    }

    @Test func emptyScopeShowsMessage() {
        let settings = InMemorySettingsStore()
        settings.scope = StudyScope(levels: [.a1], lessonRange: 1...2)
        let vm = PracticeViewModel(seed: seed, settings: settings, repository: InMemoryProgressRepository())
        #expect(vm.makeSession(for: .verbForms) == nil)
        #expect(vm.message == PracticeViewModel.emptyScopeMessage)
    }

    @Test func reviewRebuildsQuestionsForWrongKeysAndSkipsGhosts() throws {
        let repo = InMemoryProgressRepository()
        let word = try #require(seed.words.first { $0.headword == "食べる" })
        let key = ItemKey.verb(word.id, .te)
        repo.record(key, pillar: .katsuyou, correct: false, mode: .choice, at: Date())
        repo.record(ItemKey("verb:999999:te"), pillar: .katsuyou, correct: false, mode: .choice, at: Date())
        let vm = ReviewViewModel(repository: repo, seed: seed, settings: InMemorySettingsStore())
        #expect(vm.weak.count == 2)
        #expect(vm.weak.first { $0.key == key }?.title == "食べる")
        let session = try #require(vm.makeSession())
        #expect(session.questions.map(\.id) == [key])
    }
}
