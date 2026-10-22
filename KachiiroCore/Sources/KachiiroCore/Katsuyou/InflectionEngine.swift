/// Plain/polite × non-past/past × affirmative/negative for verbs, adjectives and nouns.
public enum InflectionEngine {
    public static func inflect(_ lexeme: Lexeme, cell: InflectionCell) -> Conjugation {
        switch lexeme.kind {
        case .godan, .ichidan, .suruKuru: verb(lexeme, cell)
        case .iAdj: iAdjective(lexeme, cell)
        case .naAdj, .noun: copula(lexeme, cell)
        }
    }

    private static func fallback(_ lexeme: Lexeme) -> Conjugation {
        Conjugation(display: lexeme.headword, accepted: [lexeme.headword, lexeme.reading])
    }

    private static func verb(_ lexeme: Lexeme, _ cell: InflectionCell) -> Conjugation {
        let result: Conjugation?
        switch (cell.politeness, cell.tense, cell.polarity) {
        case (.plain, .nonPast, .affirmative):
            result = KatsuyouEngine.conjugate(lexeme, form: .dictionary)
        case (.plain, .nonPast, .negative):
            result = KatsuyouEngine.conjugate(lexeme, form: .nai)
        case (.plain, .past, .affirmative):
            result = KatsuyouEngine.conjugate(lexeme, form: .ta)
        case (.plain, .past, .negative):
            result = KatsuyouEngine.conjugate(lexeme, form: .nai)?.map { swap($0, "ない", "なかった") }
        case (.polite, .nonPast, .affirmative):
            result = KatsuyouEngine.conjugate(lexeme, form: .masu)
        case (.polite, .nonPast, .negative):
            result = KatsuyouEngine.conjugate(lexeme, form: .masu)?.map { swap($0, "ます", "ません") }
        case (.polite, .past, .affirmative):
            result = KatsuyouEngine.conjugate(lexeme, form: .masu)?.map { swap($0, "ます", "ました") }
        case (.polite, .past, .negative):
            result = KatsuyouEngine.conjugate(lexeme, form: .masu)?.map { swap($0, "ます", "ませんでした") }
        }
        return result ?? fallback(lexeme)
    }

    private static func swap(_ s: String, _ suffix: String, _ replacement: String) -> String? {
        s.hasSuffix(suffix) ? String(s.dropLast(suffix.count)) + replacement : nil
    }

    private static func iAdjective(_ lexeme: Lexeme, _ cell: InflectionCell) -> Conjugation {
        let plain: (String) -> String? = { s in
            guard s.hasSuffix("い") else { return nil }
            // いい → よ + suffix (かっこいい, 気持ちいい) but not かわいい
            let stem = (s.hasSuffix("いい") && !s.hasSuffix("わいい")) ? String(s.dropLast(2)) + "よ" : String(s.dropLast())
            let plainAffirmativeIsDictionary = cell.tense == .nonPast && cell.polarity == .affirmative
            if plainAffirmativeIsDictionary { return s }
            switch (cell.tense, cell.polarity) {
            case (.nonPast, .negative): return stem + "くない"
            case (.past, .affirmative): return stem + "かった"
            default: return stem + "くなかった"
            }
        }
        let polite = cell.politeness == .polite
        let transform: (String) -> String? = { s in plain(s).map { polite ? $0 + "です" : $0 } }
        return Conjugation.combine(
            headword: transform(lexeme.headword).map { [$0] } ?? [],
            reading: transform(lexeme.reading).map { [$0] } ?? []
        ) ?? fallback(lexeme)
    }

    private static func copula(_ lexeme: Lexeme, _ cell: InflectionCell) -> Conjugation {
        let forms: [String]
        switch (cell.politeness, cell.tense, cell.polarity) {
        case (.plain, .nonPast, .affirmative): forms = ["だ"]
        case (.plain, .nonPast, .negative): forms = ["じゃない"]
        case (.plain, .past, .affirmative): forms = ["だった"]
        case (.plain, .past, .negative): forms = ["じゃなかった"]
        case (.polite, .nonPast, .affirmative): forms = ["です"]
        case (.polite, .nonPast, .negative): forms = ["じゃないです", "ではありません"]
        case (.polite, .past, .affirmative): forms = ["でした"]
        case (.polite, .past, .negative): forms = ["じゃなかったです", "ではありませんでした"]
        }
        return Conjugation.combine(
            headword: forms.map { lexeme.headword + $0 },
            reading: forms.map { lexeme.reading + $0 }
        ) ?? fallback(lexeme)
    }
}
