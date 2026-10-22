import Testing
@testable import KachiiroCore

@Suite struct SeedDataTests {
    let seed = TestSeed.shared

    @Test func counts() {
        #expect(seed.words.count == 3797)
        #expect(seed.patterns.count == 259)
        #expect(seed.kanji.count == 659)
        #expect(Set(seed.kanji.map(\.kanji)).count == 429)
        #expect(Set(seed.words.map(\.id)).count == 3797)
    }

    @Test func noteStrippedAndSlashSplit() throws {
        let w = try #require(seed.words.first { $0.headword == "出る" && $0.contextNote.contains("せき") })
        #expect(w.reading == "でる")
        #expect(w.pos == .verb2)
        #expect(w.contextNote == "せき / 鼻水が出る")
        #expect(w.pitch == "で↓る")
    }

    @Test func a1VerbKeepsDictionaryForm() throws {
        let w = try #require(seed.words.first { $0.headword == "会う" })
        #expect(w.reading == "あう")
        #expect(w.pos == .verb1)
    }

    @Test func suruNounsBecomeVerbs() throws {
        let w = try #require(seed.words.first { $0.headword == "案内する" })
        #expect(w.pos == .verb3)
        #expect(seed.words.filter { $0.pos == .verb3 }.count == 151)
    }

    @Test func naAdjectivesHaveNoNaSuffix() {
        let nas = seed.words.filter { $0.pos == .naAdj }
        #expect(nas.count == 65)
        #expect(nas.allSatisfy { !$0.headword.contains("（な）") && !$0.headword.contains("(な)") })
    }

    @Test func verbsAndAdjectivesAreFullyCleaned() {
        let bad = seed.words.filter { $0.pos.isVerb || $0.pos == .iAdj || $0.pos == .naAdj }
            .filter { w in [w.headword, w.reading].contains { s in s.contains { "（）()／".contains($0) } } }
        #expect(bad.isEmpty)
    }

    @Test func partOfSpeechTagMapping() {
        #expect(PartOfSpeech(seedTag: "V［1］") == .verb1)
        #expect(PartOfSpeech(seedTag: "N/V［3］") == .verb3)
        #expect(PartOfSpeech(seedTag: "Other") == .other)
        #expect(PartOfSpeech(seedTag: " ") == .other)
    }

    @Test func studyScopeFiltering() {
        let scope = StudyScope(levels: [.a21], lessonRange: 3...5)
        #expect(scope.contains(level: .a21, lesson: 4))
        #expect(!scope.contains(level: .a21, lesson: 6))
        #expect(!scope.contains(level: .a1, lesson: 4))
        #expect(StudyScope.all.contains(level: .a22, lesson: 18))
    }
}
