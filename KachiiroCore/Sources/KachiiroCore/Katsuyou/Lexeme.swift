public enum LexemeKind: String, Sendable, Codable, CaseIterable {
    case godan, ichidan, suruKuru, iAdj, naAdj, noun

    public var isVerb: Bool { self == .godan || self == .ichidan || self == .suruKuru }
}

/// A word that can be inflected: the written headword, its kana reading and its group.
public struct Lexeme: Sendable, Equatable {
    public let headword: String
    public let reading: String
    public let kind: LexemeKind

    public init(headword: String, reading: String, kind: LexemeKind) {
        self.headword = headword
        self.reading = reading
        self.kind = kind
    }

    public init?(word: Word) {
        let kind: LexemeKind
        switch word.pos {
        case .verb1: kind = .godan
        case .verb2: kind = .ichidan
        case .verb3: kind = .suruKuru
        case .iAdj: kind = .iAdj
        case .naAdj: kind = .naAdj
        case .noun: kind = .noun
        case .expression, .other: return nil
        }
        self.init(headword: word.headword, reading: word.reading, kind: kind)
    }
}
