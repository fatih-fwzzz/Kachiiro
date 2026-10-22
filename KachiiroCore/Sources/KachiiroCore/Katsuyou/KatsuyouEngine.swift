/// Verb conjugation. Runs the same algorithm on the headword and on the reading and merges the results.
public enum KatsuyouEngine {
    /// - Parameter kind: overrides the lexeme's group (used to build wrong-group distractors).
    /// - Returns: `nil` when the form does not exist for this verb or the string does not fit the group.
    public static func conjugate(_ lexeme: Lexeme, form: VerbForm, as kind: LexemeKind? = nil) -> Conjugation? {
        let group = kind ?? lexeme.kind
        guard group.isVerb else { return nil }
        let reading = lexeme.reading
        var quirks = Quirks()
        if group == .godan {
            quirks.isAru = reading.hasSuffix("ある")
            quirks.isIku = reading.hasSuffix("いく")
            if quirks.isAru, [.potential, .passive, .causative, .causativePassive].contains(form) { return nil }
            if reading.hasSuffix("ぬ"), form == .causativePassive { return nil }
        }
        guard let h = inflect(lexeme.headword, group, form, quirks),
              let r = inflect(lexeme.reading, group, form, quirks) else { return nil }
        return Conjugation.combine(headword: h, reading: r)
    }

    private struct Quirks {
        var isAru = false
        var isIku = false
    }

    private struct GodanRow {
        let a: String, i: String, e: String, o: String
    }

    private static let godanRows: [Character: GodanRow] = [
        "う": GodanRow(a: "わ", i: "い", e: "え", o: "お"),
        "く": GodanRow(a: "か", i: "き", e: "け", o: "こ"),
        "ぐ": GodanRow(a: "が", i: "ぎ", e: "げ", o: "ご"),
        "す": GodanRow(a: "さ", i: "し", e: "せ", o: "そ"),
        "つ": GodanRow(a: "た", i: "ち", e: "て", o: "と"),
        "ぬ": GodanRow(a: "な", i: "に", e: "ね", o: "の"),
        "ぶ": GodanRow(a: "ば", i: "び", e: "べ", o: "ぼ"),
        "む": GodanRow(a: "ま", i: "み", e: "め", o: "も"),
        "る": GodanRow(a: "ら", i: "り", e: "れ", o: "ろ"),
    ]

    private static func inflect(_ s: String, _ group: LexemeKind, _ form: VerbForm, _ q: Quirks) -> [String]? {
        switch group {
        case .godan: godan(s, form, q)
        case .ichidan: ichidan(s, form)
        case .suruKuru: suruKuru(s, form)
        default: nil
        }
    }

    private static func godan(_ s: String, _ form: VerbForm, _ q: Quirks) -> [String]? {
        guard let last = s.last, let row = godanRows[last] else { return nil }
        let p = String(s.dropLast())
        switch form {
        case .nai:
            if q.isAru, s.hasSuffix("ある") { return [String(s.dropLast(2)) + "ない"] }
            return [p + row.a + "ない"]
        case .masu: return [p + row.i + "ます"]
        case .dictionary: return [s]
        case .ba: return [p + row.e + "ば"]
        case .volitional: return [p + row.o + "う"]
        case .te, .ta:
            let isTe = form == .te
            let t = isTe ? "て" : "た"
            let d = isTe ? "で" : "だ"
            if q.isIku, last == "く" { return [p + "っ" + t] }
            switch last {
            case "う", "つ", "る": return [p + "っ" + t]
            case "ぬ", "ぶ", "む": return [p + "ん" + d]
            case "く": return [p + "い" + t]
            case "ぐ": return [p + "い" + d]
            case "す": return [p + "し" + t]
            default: return nil
            }
        case .potential: return [p + row.e + "る"]
        case .passive: return [p + row.a + "れる"]
        case .causative: return [p + row.a + "せる"]
        case .causativePassive:
            if last == "す" { return [p + row.a + "せられる"] }
            return [p + row.a + "される", p + row.a + "せられる"]
        }
    }

    private static func ichidan(_ s: String, _ form: VerbForm) -> [String]? {
        guard s.hasSuffix("る") else { return nil }
        let stem = String(s.dropLast())
        switch form {
        case .nai: return [stem + "ない"]
        case .masu: return [stem + "ます"]
        case .dictionary: return [s]
        case .ba: return [stem + "れば"]
        case .volitional: return [stem + "よう"]
        case .te: return [stem + "て"]
        case .ta: return [stem + "た"]
        case .potential, .passive: return [stem + "られる"]
        case .causative: return [stem + "させる"]
        case .causativePassive: return [stem + "させられる"]
        }
    }

    private static func suruKuru(_ s: String, _ form: VerbForm) -> [String]? {
        if s.hasSuffix("する") {
            let p = String(s.dropLast(2))
            let tail: String
            switch form {
            case .nai: tail = "しない"
            case .masu: tail = "します"
            case .dictionary: tail = "する"
            case .ba: tail = "すれば"
            case .volitional: tail = "しよう"
            case .te: tail = "して"
            case .ta: tail = "した"
            case .potential: tail = "できる"
            case .passive: tail = "される"
            case .causative: tail = "させる"
            case .causativePassive: tail = "させられる"
            }
            return [p + tail]
        }
        let written = s.hasSuffix("来る")
        guard written || s.hasSuffix("くる") else { return nil }
        let p = String(s.dropLast(2))
        let (stem, ending): (String, String)
        switch form {
        case .nai: (stem, ending) = ("こ", "ない")
        case .masu: (stem, ending) = ("き", "ます")
        case .dictionary: (stem, ending) = ("く", "る")
        case .ba: (stem, ending) = ("く", "れば")
        case .volitional: (stem, ending) = ("こ", "よう")
        case .te: (stem, ending) = ("き", "て")
        case .ta: (stem, ending) = ("き", "た")
        case .potential, .passive: (stem, ending) = ("こ", "られる")
        case .causative: (stem, ending) = ("こ", "させる")
        case .causativePassive: (stem, ending) = ("こ", "させられる")
        }
        return [p + (written ? "来" : stem) + ending]
    }
}
