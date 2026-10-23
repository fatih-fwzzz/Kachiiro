import Foundation

/// Stable identity of a quizzable item; persisted by the SRS.
/// Formats: `verb:{wordId}:{form}`, `infl:{wordId}:{cellRaw}`, `vocab:{wordId}:{m2w|w2m}`,
/// `kanji:{rowId}:{r|w}`, `pitch:{wordId}`, `pattern:{patternId}`,
/// `register:{wordId}:{tense}-{polarity}:{p2n|n2p}`, `dict:{wordId}`, `sent:{patternId}`,
/// `keigo:v:{verbId}:{son|ken|tei}`, `keigo:s:{sentenceId}`, `uchi:{id}`, and
/// `ai:{drill}:{uuid}` for AI-generated items (never persisted, cannot be rebuilt).
public struct ItemKey: Hashable, Codable, Sendable {
    public let raw: String

    public init(_ raw: String) { self.raw = raw }

    public init(from decoder: Decoder) throws {
        raw = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }

    public static func verb(_ wordId: Int, _ form: VerbForm) -> ItemKey { ItemKey("verb:\(wordId):\(form.rawValue)") }
    public static func infl(_ wordId: Int, _ cell: InflectionCell) -> ItemKey { ItemKey("infl:\(wordId):\(cell.raw)") }
    public static func vocab(_ wordId: Int, reverse: Bool) -> ItemKey { ItemKey("vocab:\(wordId):\(reverse ? "w2m" : "m2w")") }
    public static func kanji(_ rowId: Int, writing: Bool) -> ItemKey { ItemKey("kanji:\(rowId):\(writing ? "w" : "r")") }
    public static func pitch(_ wordId: Int) -> ItemKey { ItemKey("pitch:\(wordId)") }
    public static func pattern(_ id: Int) -> ItemKey { ItemKey("pattern:\(id)") }
    public static func register(_ wordId: Int, tense: Tense, polarity: Polarity, toPlain: Bool) -> ItemKey {
        ItemKey("register:\(wordId):\(tense.rawValue)-\(polarity.rawValue):\(toPlain ? "p2n" : "n2p")")
    }
    public static func dict(_ wordId: Int) -> ItemKey { ItemKey("dict:\(wordId)") }
    public static func sent(_ patternId: Int) -> ItemKey { ItemKey("sent:\(patternId)") }
    public static func keigoVerb(_ id: Int, _ level: KeigoLevel) -> ItemKey { ItemKey("keigo:v:\(id):\(level.short)") }
    public static func keigoSentence(_ id: Int) -> ItemKey { ItemKey("keigo:s:\(id)") }
    public static func uchiSoto(_ id: Int) -> ItemKey { ItemKey("uchi:\(id)") }
    public static func generated(_ drill: DrillKind) -> ItemKey { ItemKey("ai:\(drill.rawValue):\(UUID().uuidString)") }

    public var isGenerated: Bool { prefix == "ai" }

    /// The `:`-separated parts after the prefix.
    public var parts: [String] {
        raw.split(separator: ":", omittingEmptySubsequences: false).dropFirst().map(String.init)
    }

    public var prefix: String {
        raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
    }

    public var drill: DrillKind? {
        switch prefix {
        case "verb": .verbForms
        case "infl": .inflectionMatrix
        case "vocab": .vocab
        case "kanji": .kanji
        case "pitch": .pitch
        case "pattern": .patternRecognition
        case "register": .registerShift
        case "dict": .dictation
        case "sent": .sentenceListening
        case "keigo": .keigo
        case "uchi": .uchiSoto
        default: nil
        }
    }

    /// First numeric part (word id, row id or pattern id).
    public var id: Int? { parts.first.flatMap(Int.init) }
}

public extension ItemKey {
    /// Process-independent seed (FNV-1a) so a key always rebuilds the same question.
    var stableSeed: UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return hash
    }
}
