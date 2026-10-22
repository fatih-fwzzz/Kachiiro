public enum Pillar: String, CaseIterable, Codable, Sendable {
    case katsuyou, goi, bunpou, choukai, kaiwa

    public var title: String {
        switch self {
        case .katsuyou: "Katsuyou 活用"
        case .goi: "Goi 語彙"
        case .bunpou: "Bunpou 文法"
        case .choukai: "Choukai 聴解"
        case .kaiwa: "Kaiwa 会話"
        }
    }
}
