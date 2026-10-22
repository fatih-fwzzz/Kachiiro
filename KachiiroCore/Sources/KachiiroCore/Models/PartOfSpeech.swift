public enum PartOfSpeech: Sendable, Equatable, Hashable, Codable {
    case verb1, verb2, verb3, iAdj, naAdj, noun, expression, other

    public init(seedTag: String) {
        switch seedTag {
        case "V［1］": self = .verb1
        case "V［2］": self = .verb2
        case "V［3］", "N/V［3］": self = .verb3
        case "イA": self = .iAdj
        case "ナA": self = .naAdj
        case "N": self = .noun
        case "Exp": self = .expression
        default: self = .other
        }
    }

    public var seedTag: String {
        switch self {
        case .verb1: "V［1］"
        case .verb2: "V［2］"
        case .verb3: "V［3］"
        case .iAdj: "イA"
        case .naAdj: "ナA"
        case .noun: "N"
        case .expression: "Exp"
        case .other: "Other"
        }
    }

    public var label: String {
        switch self {
        case .verb1: "verb (group 1)"
        case .verb2: "verb (group 2)"
        case .verb3: "verb (group 3)"
        case .iAdj: "い-adjective"
        case .naAdj: "な-adjective"
        case .noun: "noun"
        case .expression: "expression"
        case .other: "word"
        }
    }

    public var isVerb: Bool { self == .verb1 || self == .verb2 || self == .verb3 }

    public init(from decoder: Decoder) throws {
        self.init(seedTag: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(seedTag)
    }
}
