import Testing
@testable import KachiiroCore

@Suite struct InflectionEngineTests {
    /// Order: polite nonPast aff/neg, polite past aff/neg, plain nonPast aff/neg, plain past aff/neg.
    static let cells: [InflectionCell] = [
        InflectionCell(politeness: .polite, tense: .nonPast, polarity: .affirmative),
        InflectionCell(politeness: .polite, tense: .nonPast, polarity: .negative),
        InflectionCell(politeness: .polite, tense: .past, polarity: .affirmative),
        InflectionCell(politeness: .polite, tense: .past, polarity: .negative),
        InflectionCell(politeness: .plain, tense: .nonPast, polarity: .affirmative),
        InflectionCell(politeness: .plain, tense: .nonPast, polarity: .negative),
        InflectionCell(politeness: .plain, tense: .past, polarity: .affirmative),
        InflectionCell(politeness: .plain, tense: .past, polarity: .negative),
    ]

    /// Matrix from "Plain form and Polite form.pdf".
    static let matrix: [(String, LexemeKind, [String])] = [
        ("いしゃ", .noun, ["いしゃです", "いしゃじゃないです", "いしゃでした", "いしゃじゃなかったです", "いしゃだ", "いしゃじゃない", "いしゃだった", "いしゃじゃなかった"]),
        ("おきる", .ichidan, ["おきます", "おきません", "おきました", "おきませんでした", "おきる", "おきない", "おきた", "おきなかった"]),
        ("しずか", .naAdj, ["しずかです", "しずかじゃないです", "しずかでした", "しずかじゃなかったです", "しずかだ", "しずかじゃない", "しずかだった", "しずかじゃなかった"]),
        ("ふるい", .iAdj, ["ふるいです", "ふるくないです", "ふるかったです", "ふるくなかったです", "ふるい", "ふるくない", "ふるかった", "ふるくなかった"]),
    ]

    @Test func pdfMatrix() {
        for (kana, kind, expected) in Self.matrix {
            let l = Lexeme(headword: kana, reading: kana, kind: kind)
            for (cell, want) in zip(Self.cells, expected) {
                #expect(InflectionEngine.inflect(l, cell: cell).display == want, "\(kana) \(cell.raw)")
            }
        }
    }

    @Test func cellRawRoundTrip() {
        #expect(InflectionCell.all.count == 8)
        for c in InflectionCell.all { #expect(InflectionCell(raw: c.raw) == c) }
        #expect(InflectionCell.all.contains { $0.raw == "plain-past-negative" })
    }

    @Test func politeNegativeAlternatives() {
        let l = Lexeme(headword: "医者", reading: "いしゃ", kind: .noun)
        let c = InflectionEngine.inflect(l, cell: InflectionCell(politeness: .polite, tense: .past, polarity: .negative))
        #expect(c.display == "医者じゃなかったです")
        #expect(c.accepted.contains("医者ではありませんでした"))
        #expect(c.accepted.contains("いしゃじゃなかったです"))
    }

    @Test func iiAdjectives() {
        let plainNeg = InflectionCell(politeness: .plain, tense: .nonPast, polarity: .negative)
        let plainPastNeg = InflectionCell(politeness: .plain, tense: .past, polarity: .negative)
        let plainPast = InflectionCell(politeness: .plain, tense: .past, polarity: .affirmative)
        let politePastNeg = InflectionCell(politeness: .polite, tense: .past, polarity: .negative)
        let ii = Lexeme(headword: "いい", reading: "いい", kind: .iAdj)
        #expect(InflectionEngine.inflect(ii, cell: plainNeg).display == "よくない")
        let kakko = Lexeme(headword: "かっこいい", reading: "かっこいい", kind: .iAdj)
        #expect(InflectionEngine.inflect(kakko, cell: plainPastNeg).display == "かっこよくなかった")
        #expect(InflectionEngine.inflect(kakko, cell: plainPast).display == "かっこよかった")
        let kimochi = Lexeme(headword: "気持ちいい", reading: "きもちいい", kind: .iAdj)
        #expect(InflectionEngine.inflect(kimochi, cell: politePastNeg).display == "気持ちよくなかったです")
        let kawaii = Lexeme(headword: "かわいい", reading: "かわいい", kind: .iAdj)
        #expect(InflectionEngine.inflect(kawaii, cell: plainNeg).display == "かわいくない")
    }

    @Test func aruCompoundNegatives() {
        let l = Lexeme(headword: "興味がある", reading: "きょうみがある", kind: .godan)
        let plainNeg = InflectionCell(politeness: .plain, tense: .nonPast, polarity: .negative)
        let plainPastNeg = InflectionCell(politeness: .plain, tense: .past, polarity: .negative)
        let politeNeg = InflectionCell(politeness: .polite, tense: .nonPast, polarity: .negative)
        #expect(InflectionEngine.inflect(l, cell: plainNeg).display == "興味がない")
        #expect(InflectionEngine.inflect(l, cell: plainPastNeg).display == "興味がなかった")
        #expect(InflectionEngine.inflect(l, cell: plainPastNeg).accepted.contains("きょうみがなかった"))
        #expect(InflectionEngine.inflect(l, cell: politeNeg).display == "興味がありません")
    }

    @Test func seedWideCellsNonEmpty() {
        for word in TestSeed.shared.words {
            guard let l = Lexeme(word: word), !l.kind.isVerb else { continue }
            for cell in InflectionCell.all {
                let c = InflectionEngine.inflect(l, cell: cell)
                #expect(!c.display.isEmpty && c.accepted.contains(c.display))
            }
        }
    }

    @Test func seedWideVerbCellsUseEngine() {
        for word in TestSeed.shared.words where word.pos.isVerb {
            let l = Lexeme(word: word)!
            for cell in InflectionCell.all where cell.raw != "plain-nonPast-affirmative" {
                let c = InflectionEngine.inflect(l, cell: cell)
                #expect(c.display != l.headword, "\(word.headword) \(cell.raw)")
            }
        }
    }
}
