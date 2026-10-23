import Foundation

public enum KeigoEngine {
    /// Longest first; applied in order.
    private static let kanaReplacements: [(String, String)] = [
        ("召し上が", "めしあが"), ("申し上げ", "もうしあげ"), ("上げ", "あげ"), ("伺", "うかが"), ("参", "まい"),
        ("申", "もう"), ("拝見", "はいけん"), ("拝聴", "はいちょう"), ("拝借", "はいしゃく"), ("覧", "らん"),
        ("存", "ぞん"), ("目", "め"), ("見え", "みえ"), ("越し", "こし"), ("聞き", "きき"), ("聞か", "きか"),
        ("訪ね", "たずね"), ("休み", "やすみ"), ("召し", "めし"), ("思い", "おもい"), ("思わ", "おもわ"),
        ("分かり", "わかり"), ("承知", "しょうち"), ("待ち", "まち"), ("待た", "また"), ("書き", "かき"),
        ("書か", "かか"), ("読み", "よみ"), ("読ま", "よま"), ("帰り", "かえり"), ("帰ら", "かえら"),
        ("失礼", "しつれい"), ("使い", "つかい"), ("使わ", "つかわ"), ("持ち", "もち"), ("持た", "もた"),
        ("座り", "すわり"), ("決め", "きめ"), ("送り", "おくり"), ("送ら", "おくら"), ("手伝い", "てつだい"),
        ("案内", "あんない"), ("説明", "せつめい"), ("連絡", "れんらく"), ("電話", "でんわ"), ("借り", "かり"),
        ("見せ", "みせ"), ("住まい", "すまい"), ("住み", "すみ"), ("会い", "あい"), ("会わ", "あわ"),
        ("入れ", "いれ"), ("行か", "いか"), ("来られ", "こられ"), ("言われ", "いわれ"), ("飲ま", "のま"),
    ]

    private static let kanjiSpellings: [(String, String)] = [
        ("いたし", "致し"), ("いただき", "頂き"), ("くださ", "下さ"), ("ご存じ", "ご存知"),
    ]

    /// `form`, its all-kana spelling, and alternative kanji spellings; de-duplicated, order kept.
    public static func variants(of form: String) -> [String] {
        var kana = form
        for (from, to) in kanaReplacements { kana = kana.replacingOccurrences(of: from, with: to) }
        var out = [form, kana]
        for (from, to) in kanjiSpellings where form.contains(from) {
            out.append(form.replacingOccurrences(of: from, with: to))
        }
        return dedup(out)
    }

    public static func forms(_ verb: KeigoVerb, _ level: KeigoLevel) -> [String] {
        switch level {
        case .sonkeigo: verb.sonkeigo
        case .kenjougo: verb.kenjougo
        case .teineigo: verb.teineigo
        }
    }

    public static func accepted(_ verb: KeigoVerb, _ level: KeigoLevel) -> [String] {
        var out = forms(verb, level).flatMap(variants(of:))
        if level == .sonkeigo, let r = verb.rareru { out += variants(of: r) }
        return dedup(out)
    }

    static func expand(keyPhrases: [[String]]) -> [[String]] {
        keyPhrases.map { dedup($0.flatMap(variants(of:))) }
    }

    private static func dedup(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }
}
