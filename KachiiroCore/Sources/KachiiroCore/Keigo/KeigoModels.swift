import Foundation

public enum KeigoLevel: String, Codable, Sendable, Equatable, CaseIterable {
    case sonkeigo, kenjougo, teineigo

    public var short: String {
        switch self {
        case .sonkeigo: "son"
        case .kenjougo: "ken"
        case .teineigo: "tei"
        }
    }

    public var label: String {
        switch self {
        case .sonkeigo: "尊敬語 · Respectful"
        case .kenjougo: "謙譲語 · Humble"
        case .teineigo: "丁寧語 · Courteous"
        }
    }

    public var rule: String {
        switch self {
        case .sonkeigo: "尊敬語 raises the other person's action."
        case .kenjougo: "謙譲語 lowers your own action."
        case .teineigo: "丁寧語 makes the whole sentence courteous."
        }
    }
}

public enum Listener: String, Codable, Sendable, Equatable, CaseIterable {
    case boss, teacher, customer, client, stranger, colleague

    public var label: String {
        switch self {
        case .boss: "your manager"
        case .teacher: "your teacher"
        case .customer: "a customer"
        case .client: "a client"
        case .stranger: "a stranger"
        case .colleague: "a colleague"
        }
    }
}

/// All forms are written in ます/です form.
public struct KeigoVerb: Codable, Sendable, Equatable {
    public let id: Int
    public let plain: String
    public let reading: String
    public let meaning: String
    public let polite: String
    public let sonkeigo: [String]
    public let kenjougo: [String]
    public let teineigo: [String]
    public let rareru: String?
}

public struct KeigoSentence: Codable, Sendable, Equatable {
    public let id: Int
    public let situation: String
    public let listener: Listener
    public let target: KeigoLevel
    public let plain: String
    public let answers: [String]
    public var keyPhrases: [[String]]
    public let wrong: [String]
    public let explanation: String
}

public struct UchiSotoItem: Codable, Sendable, Equatable {
    public let id: Int
    public let situation: String
    public let question: String
    public let choices: [String]
    public let answer: String
    public let explanation: String
}

public struct ShadowingLine: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let text: String
    public let reading: String?
    public let meaning: String
    public let pitch: PitchPattern?

    public init(id: String, text: String, reading: String?, meaning: String, pitch: PitchPattern? = nil) {
        self.id = id
        self.text = text
        self.reading = reading
        self.meaning = meaning
        self.pitch = pitch
    }

    private enum CodingKeys: String, CodingKey { case id, text, reading, meaning }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            text: try c.decode(String.self, forKey: .text),
            reading: try c.decodeIfPresent(String.self, forKey: .reading),
            meaning: try c.decode(String.self, forKey: .meaning)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encodeIfPresent(reading, forKey: .reading)
        try c.encode(meaning, forKey: .meaning)
    }
}

public struct KeigoContent: Codable, Sendable, Equatable {
    public var verbs: [KeigoVerb]
    public var sentences: [KeigoSentence]
    public var uchiSoto: [UchiSotoItem]
    public var shadowing: [ShadowingLine]

    public static func load(from data: Data) throws -> KeigoContent {
        var content = try JSONDecoder().decode(KeigoContent.self, from: data)
        content.sentences = content.sentences.map { s in
            var s = s
            s.keyPhrases = KeigoEngine.expand(keyPhrases: s.keyPhrases)
            return s
        }
        return content
    }

    public static let bundled: KeigoContent = {
        do {
            guard let url = Bundle.module.url(forResource: "keigo", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try load(from: Data(contentsOf: url))
        } catch {
            fatalError("keigo.json missing or invalid: \(error)")
        }
    }()
}
