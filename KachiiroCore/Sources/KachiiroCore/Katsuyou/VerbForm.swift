public enum VerbForm: String, Sendable, Codable, CaseIterable {
    case nai, masu, dictionary, ba, volitional, te, ta, potential, passive, causative, causativePassive

    public var label: String {
        switch self {
        case .nai: "ない形 / nai-form"
        case .masu: "ます形 / masu-form"
        case .dictionary: "辞書形 / dictionary form"
        case .ba: "ば形 / ba-form"
        case .volitional: "う形 / volitional"
        case .te: "て形 / te-form"
        case .ta: "た形 / ta-form"
        case .potential: "可能形 / potential"
        case .passive: "受身形 / passive"
        case .causative: "使役形 / causative"
        case .causativePassive: "使役受身 / causative-passive"
        }
    }

    public var shortLabel: String {
        switch self {
        case .nai: "ない"
        case .masu: "ます"
        case .dictionary: "辞書"
        case .ba: "ば"
        case .volitional: "う"
        case .te: "て"
        case .ta: "た"
        case .potential: "可能"
        case .passive: "受身"
        case .causative: "使役"
        case .causativePassive: "使役受身"
        }
    }
}
