/// One-line rule explanations shown after answering.
public enum ConjugationRule {
    public static func groupName(_ kind: LexemeKind) -> String {
        switch kind {
        case .godan: "Group 1"
        case .ichidan: "Group 2"
        case .suruKuru: "Group 3"
        case .iAdj: "い-adjective"
        case .naAdj: "な-adjective"
        case .noun: "Noun"
        }
    }

    public static func hint(_ lexeme: Lexeme, form: VerbForm) -> String {
        let group = groupName(lexeme.kind)
        switch lexeme.kind {
        case .godan:
            switch form {
            case .te, .ta:
                let te = form == .te
                if lexeme.reading.hasSuffix("いく") { return "\(group): 行く is irregular → いって/いった" }
                switch lexeme.reading.last {
                case "う", "つ", "る": return "\(group): う・つ・る → って/った"
                case "ぬ", "ぶ", "む": return "\(group): ぬ・ぶ・む → んで/んだ"
                case "く": return "\(group): く → \(te ? "いて" : "いた")"
                case "ぐ": return "\(group): ぐ → \(te ? "いで" : "いだ")"
                case "す": return "\(group): す → \(te ? "して" : "した")"
                default: return group
                }
            case .nai: return lexeme.reading.hasSuffix("ある") ? "ある → ない (not あらない)" : "\(group): u → a + ない"
            case .masu: return "\(group): u → i + ます"
            case .dictionary: return "\(group): dictionary form"
            case .ba: return "\(group): u → e + ば"
            case .volitional: return "\(group): u → o + う"
            case .potential: return "\(group): u → e + る"
            case .passive: return "\(group): u → a + れる"
            case .causative: return "\(group): u → a + せる"
            case .causativePassive: return "\(group): u → a + される (す-verbs: させられる)"
            }
        case .ichidan:
            switch form {
            case .nai: return "\(group): drop る + ない"
            case .masu: return "\(group): drop る + ます"
            case .dictionary: return "\(group): dictionary form"
            case .ba: return "\(group): drop る + れば"
            case .volitional: return "\(group): drop る + よう"
            case .te: return "\(group): drop る + て"
            case .ta: return "\(group): drop る + た"
            case .potential, .passive: return "\(group): drop る + られる"
            case .causative: return "\(group): drop る + させる"
            case .causativePassive: return "\(group): drop る + させられる"
            }
        default:
            return "\(group): irregular (する / くる)"
        }
    }
}
