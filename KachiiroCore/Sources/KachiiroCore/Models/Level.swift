/// Study level. Mapping to course books: A1 = 入門, A2-1 = 初級1, A2-2 = 初級2.
public enum Level: String, Codable, CaseIterable, Sendable, Comparable {
    case a1 = "A1"
    case a21 = "A2-1"
    case a22 = "A2-2"

    public var bookName: String {
        switch self {
        case .a1: "入門"
        case .a21: "初級1"
        case .a22: "初級2"
        }
    }

    public static func < (lhs: Level, rhs: Level) -> Bool {
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }
}
