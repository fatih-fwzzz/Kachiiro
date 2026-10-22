import Testing
@testable import KachiiroCore

@Suite struct KatsuyouEngineTests {
    static let forms: [VerbForm] = [
        .nai, .masu, .dictionary, .ba, .volitional, .te, .ta, .potential, .passive, .causative, .causativePassive,
    ]

    /// Rows transcribed from "Conjugation of Verbs.pdf"; "-" = no form.
    static let pdfRows: [(String, LexemeKind, [String])] = [
        ("かう", .godan, ["かわない", "かいます", "かう", "かえば", "かおう", "かって", "かった", "かえる", "かわれる", "かわせる", "かわされる"]),
        ("まつ", .godan, ["またない", "まちます", "まつ", "まてば", "まとう", "まって", "まった", "まてる", "またれる", "またせる", "またされる"]),
        ("とる", .godan, ["とらない", "とります", "とる", "とれば", "とろう", "とって", "とった", "とれる", "とられる", "とらせる", "とらされる"]),
        ("よむ", .godan, ["よまない", "よみます", "よむ", "よめば", "よもう", "よんで", "よんだ", "よめる", "よまれる", "よませる", "よまされる"]),
        ("あそぶ", .godan, ["あそばない", "あそびます", "あそぶ", "あそべば", "あそぼう", "あそんで", "あそんだ", "あそべる", "あそばれる", "あそばせる", "あそばされる"]),
        ("しぬ", .godan, ["しなない", "しにます", "しぬ", "しねば", "しのう", "しんで", "しんだ", "しねる", "しなれる", "しなせる", "-"]),
        ("かく", .godan, ["かかない", "かきます", "かく", "かけば", "かこう", "かいて", "かいた", "かける", "かかれる", "かかせる", "かかされる"]),
        ("およぐ", .godan, ["およがない", "およぎます", "およぐ", "およげば", "およごう", "およいで", "およいだ", "およげる", "およがれる", "およがせる", "およがされる"]),
        ("いく", .godan, ["いかない", "いきます", "いく", "いけば", "いこう", "いって", "いった", "いける", "いかれる", "いかせる", "いかされる"]),
        ("はなす", .godan, ["はなさない", "はなします", "はなす", "はなせば", "はなそう", "はなして", "はなした", "はなせる", "はなされる", "はなさせる", "はなさせられる"]),
        ("たべる", .ichidan, ["たべない", "たべます", "たべる", "たべれば", "たべよう", "たべて", "たべた", "たべられる", "たべられる", "たべさせる", "たべさせられる"]),
        ("みる", .ichidan, ["みない", "みます", "みる", "みれば", "みよう", "みて", "みた", "みられる", "みられる", "みさせる", "みさせられる"]),
        ("する", .suruKuru, ["しない", "します", "する", "すれば", "しよう", "して", "した", "できる", "される", "させる", "させられる"]),
        ("くる", .suruKuru, ["こない", "きます", "くる", "くれば", "こよう", "きて", "きた", "こられる", "こられる", "こさせる", "こさせられる"]),
    ]

    @Test func pdfTable() {
        for (kana, kind, expected) in Self.pdfRows {
            let lexeme = Lexeme(headword: kana, reading: kana, kind: kind)
            for (form, want) in zip(Self.forms, expected) {
                let got = KatsuyouEngine.conjugate(lexeme, form: form)
                if want == "-" {
                    #expect(got == nil, "\(kana) \(form)")
                } else {
                    #expect(got?.display == want, "\(kana) \(form): \(got?.display ?? "nil") != \(want)")
                }
            }
        }
    }

    @Test func kawauCausativePassiveAcceptsBoth() throws {
        let c = try #require(KatsuyouEngine.conjugate(Lexeme(headword: "かう", reading: "かう", kind: .godan), form: .causativePassive))
        #expect(c.accepted.contains("かわされる"))
        #expect(c.accepted.contains("かわせられる"))
    }

    @Test func ikuCompounds() throws {
        let l = Lexeme(headword: "持って行く", reading: "もっていく", kind: .godan)
        #expect(KatsuyouEngine.conjugate(l, form: .te)?.display == "持って行って")
        #expect(KatsuyouEngine.conjugate(l, form: .te)?.accepted.contains("もっていって") == true)
        let k = Lexeme(headword: "行く", reading: "いく", kind: .godan)
        let ta = try #require(KatsuyouEngine.conjugate(k, form: .ta))
        #expect(ta.display == "行った")
        #expect(ta.accepted.contains("いった"))
        let u = Lexeme(headword: "うまくいく", reading: "うまくいく", kind: .godan)
        #expect(KatsuyouEngine.conjugate(u, form: .te)?.display == "うまくいって")
    }

    @Test func aruCompounds() {
        let l = Lexeme(headword: "興味がある", reading: "きょうみがある", kind: .godan)
        #expect(KatsuyouEngine.conjugate(l, form: .nai)?.display == "興味がない")
        #expect(KatsuyouEngine.conjugate(l, form: .nai)?.accepted.contains("きょうみがない") == true)
        #expect(KatsuyouEngine.conjugate(l, form: .masu)?.display == "興味があります")
        #expect(KatsuyouEngine.conjugate(l, form: .potential) == nil)
        #expect(KatsuyouEngine.conjugate(l, form: .passive) == nil)
        #expect(KatsuyouEngine.conjugate(l, form: .causative) == nil)
        #expect(KatsuyouEngine.conjugate(l, form: .causativePassive) == nil)
    }

    @Test func kuruWrittenKeepsOkurigana() {
        let k = Lexeme(headword: "来る", reading: "くる", kind: .suruKuru)
        #expect(KatsuyouEngine.conjugate(k, form: .nai)?.display == "来ない")
        #expect(KatsuyouEngine.conjugate(k, form: .masu)?.display == "来ます")
        #expect(KatsuyouEngine.conjugate(k, form: .potential)?.display == "来られる")
        #expect(KatsuyouEngine.conjugate(k, form: .causativePassive)?.display == "来させられる")
        #expect(KatsuyouEngine.conjugate(k, form: .causativePassive)?.accepted.contains("こさせられる") == true)
        let c = Lexeme(headword: "遊びに来る", reading: "あそびにくる", kind: .suruKuru)
        #expect(KatsuyouEngine.conjugate(c, form: .nai)?.display == "遊びに来ない")
        let kana = Lexeme(headword: "あそびにくる", reading: "あそびにくる", kind: .suruKuru)
        #expect(KatsuyouEngine.conjugate(kana, form: .nai)?.display == "あそびにこない")
    }

    @Test func suruCompounds() {
        let u = Lexeme(headword: "うちあわせをする", reading: "うちあわせをする", kind: .suruKuru)
        #expect(KatsuyouEngine.conjugate(u, form: .nai)?.display == "うちあわせをしない")
        let k = Lexeme(headword: "加熱する", reading: "かねつする", kind: .suruKuru)
        #expect(KatsuyouEngine.conjugate(k, form: .ba)?.display == "加熱すれば")
        #expect(KatsuyouEngine.conjugate(k, form: .ba)?.accepted.contains("かねつすれば") == true)
    }

    @Test func kanjiIchidan() {
        let t = Lexeme(headword: "食べる", reading: "たべる", kind: .ichidan)
        let c = KatsuyouEngine.conjugate(t, form: .causativePassive)
        #expect(c?.display == "食べさせられる")
        #expect(c?.accepted == ["食べさせられる", "たべさせられる"])
    }

    @Test func kindOverrideBuildsWrongGroupForms() {
        let t = Lexeme(headword: "たべる", reading: "たべる", kind: .ichidan)
        #expect(KatsuyouEngine.conjugate(t, form: .nai, as: .godan)?.display == "たべらない")
        #expect(KatsuyouEngine.conjugate(t, form: .te, as: .godan)?.display == "たべって")
        let g = Lexeme(headword: "かく", reading: "かく", kind: .godan)
        #expect(KatsuyouEngine.conjugate(g, form: .nai, as: .ichidan) == nil)
        #expect(KatsuyouEngine.conjugate(g, form: .nai, as: .iAdj) == nil)
    }

    @Test func seedWideSanity() {
        let seed = TestSeed.shared
        var checked = 0
        for word in seed.words where word.pos.isVerb {
            let lexeme = Lexeme(word: word)!
            for form in VerbForm.allCases {
                guard let c = KatsuyouEngine.conjugate(lexeme, form: form) else { continue }
                checked += 1
                #expect(!c.display.isEmpty)
                #expect(c.accepted.contains(c.display), "\(word.headword) \(form)")
            }
            for form in [VerbForm.nai, .masu, .dictionary, .te, .ta] {
                #expect(KatsuyouEngine.conjugate(lexeme, form: form) != nil, "\(word.headword) \(word.reading) \(form)")
            }
            #expect(KatsuyouEngine.conjugate(lexeme, form: .masu)?.display.hasSuffix("ます") == true, "\(word.headword)")
        }
        #expect(checked > 4000)
    }
}
