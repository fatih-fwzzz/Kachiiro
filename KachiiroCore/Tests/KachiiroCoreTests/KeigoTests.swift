import Foundation
import Testing
@testable import KachiiroCore

@Suite struct KeigoContentTests {
    let content = KeigoContent.bundled

    @Test func contentCountsAndUniqueIds() {
        #expect(content.verbs.count == 38)
        #expect(content.sentences.count == 60)
        #expect(content.uchiSoto.count == 30)
        #expect(content.shadowing.count == 30)
        #expect(Set(content.verbs.map(\.id)).count == 38)
        #expect(Set(content.sentences.map(\.id)).count == 60)
        #expect(Set(content.uchiSoto.map(\.id)).count == 30)
        #expect(Set(content.shadowing.map(\.id)).count == 30)
    }

    @Test func allKanaVariantHasNoIdeographs() {
        func hasIdeograph(_ s: String) -> Bool { s.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) } }
        for v in content.verbs {
            let forms = v.sonkeigo + v.kenjougo + v.teineigo + [v.rareru].compactMap { $0 }
            for f in forms {
                let variants = KeigoEngine.variants(of: f)
                #expect(variants.contains { !hasIdeograph($0) }, "\(f) → \(variants)")
            }
        }
    }

    @Test func acceptedIncludesKanaAndAlternativeSpellings() throws {
        let iku = try #require(content.verbs.first { $0.plain == "行く" })
        let ken = KeigoEngine.accepted(iku, .kenjougo)
        #expect(ken.contains("まいります") && ken.contains("うかがいます"))
        let shiru = try #require(content.verbs.first { $0.plain == "知っている" })
        #expect(KeigoEngine.accepted(shiru, .sonkeigo).contains("ご存知です"))
        #expect(KeigoEngine.accepted(iku, .sonkeigo).contains("行かれます"))
    }

    @Test func sentenceKeyPhrasesDiscriminate() {
        for s in content.sentences {
            for a in s.answers {
                #expect(TypingValidator.isCorrect(a, accepted: s.answers, keyPhrases: s.keyPhrases), "#\(s.id) \(a)")
            }
            #expect(s.wrong.count == 3 && Set(s.wrong).count == 3, "#\(s.id)")
            for w in s.wrong {
                #expect(!s.answers.contains(w), "#\(s.id) \(w)")
                #expect(!TypingValidator.isCorrect(w, accepted: s.answers, keyPhrases: s.keyPhrases), "#\(s.id) wrong accepted: \(w)")
            }
        }
    }

    @Test func sentenceTargetsAreBalanced() {
        #expect(content.sentences.filter { $0.target == .sonkeigo }.count == 25)
        #expect(content.sentences.filter { $0.target == .kenjougo }.count == 25)
        #expect(content.sentences.filter { $0.target == .teineigo }.count == 10)
    }

    @Test func uchiSotoItemsAreWellFormed() {
        for i in content.uchiSoto {
            #expect(Set(i.choices).count == 4, "#\(i.id)")
            #expect(i.choices.contains(i.answer), "#\(i.id)")
        }
    }
}

@Suite struct KeigoFactoryTests {
    let seed = TestSeed.shared

    @Test func keigoFactoryIsWellFormedAndRoundTrips() {
        let factory = KeigoQuestionFactory()
        let qs = factory.makeQuestions(count: 40, scope: StudyScope(), seed: seed)
        #expect(qs.count == 40)
        #expect(qs.allSatisfy { $0.isSpeakable })
        FactoryTestSupport.expectWellFormed(qs, factory)
        FactoryTestSupport.expectRoundTrip(qs, factory, seed: seed)
    }

    @Test func everyVerbKeyBuilds() {
        let factory = KeigoQuestionFactory()
        for v in KeigoContent.bundled.verbs {
            for level in KeigoLevel.allCases where !KeigoEngine.forms(v, level).isEmpty {
                let q = factory.question(for: .keigoVerb(v.id, level), seed: seed)
                #expect(q != nil, "\(v.plain) \(level)")
                if let q { FactoryTestSupport.expectWellFormed([q], factory) }
            }
        }
    }

    @Test func uchiSotoFactoryIsWellFormedAndRoundTrips() {
        let factory = UchiSotoQuestionFactory()
        let qs = factory.makeQuestions(count: 20, scope: StudyScope(), seed: seed)
        #expect(qs.count == 20)
        #expect(qs.allSatisfy { $0.supportedModes == [.choice] })
        FactoryTestSupport.expectWellFormed(qs, factory)
        FactoryTestSupport.expectRoundTrip(qs, factory, seed: seed)
    }

    @Test func generatedKeysAreNotRebuildable() {
        let key = ItemKey.generated(.keigo)
        #expect(key.isGenerated)
        #expect(QuestionFactoryRegistry.question(for: key, seed: seed) == nil)
    }
}

@Suite struct KeyPhraseMatcherTests {
    @Test func spokenTranscriptWithPunctuationMatchesKeyPhrase() {
        #expect(TypingValidator.isCorrect("はい、部長は明日いらっしゃいます。", accepted: ["x"], keyPhrases: [["いらっしゃいます"]]))
    }

    @Test func everyGroupMustMatch() {
        let groups = [["申します"], ["いらっしゃいますか", "おいでですか"]]
        #expect(TypingValidator.isCorrect("リンと申しますが、田中部長はいらっしゃいますか", accepted: [], keyPhrases: groups))
        #expect(!TypingValidator.isCorrect("リンです、田中部長はいらっしゃいますか", accepted: [], keyPhrases: groups))
    }

    @Test func innerPunctuationIsIgnoredInExactMatch() {
        #expect(TypingValidator.isCorrect("おっしゃいます、よ", accepted: ["おっしゃいますよ"]))
    }
}

@MainActor
@Suite struct KeigoPracticeTests {
    @Test func keigoSessionDefaultsToTyping() throws {
        let settings = InMemorySettingsStore()
        settings.inputMode = .choice
        let vm = PracticeViewModel(seed: TestSeed.shared, settings: settings, repository: InMemoryProgressRepository())
        let keigo = try #require(vm.makeSession(for: .keigo))
        let uchi = try #require(vm.makeSession(for: .uchiSoto))
        #expect(keigo.mode == .typing)
        #expect(uchi.mode == .choice)
        #expect(vm.sections.contains { $0.pillar == .kaiwa && $0.drills == [.keigo, .uchiSoto] })
    }

    @Test func keyPhraseAnswerIsCorrectInSession() throws {
        let content = KeigoContent.bundled
        let s = try #require(content.sentences.first)
        let q = try #require(KeigoQuestionFactory().question(for: .keigoSentence(s.id), seed: TestSeed.shared))
        let session = QuizSessionViewModel(questions: [q], initialMode: .typing, repository: InMemoryProgressRepository())
        session.submitText("はい、" + s.answers[0] + "。")
        #expect(session.result == .correct)
    }
}
