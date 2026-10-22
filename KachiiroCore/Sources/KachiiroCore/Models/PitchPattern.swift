/// Pitch accent of one word, derived from the Irodori notation:
/// `↓` after the last high mora, a trailing `○` for flat words, `／` between alternatives.
public struct PitchPattern: Sendable, Equatable {
    public enum AccentType: String, Sendable, CaseIterable {
        case heiban, atamadaka, nakadaka, odaka
    }

    public let moraCount: Int
    /// Number of morae before the drop; `nil` for flat (heiban) words.
    public let dropAfter: Int?

    public init(moraCount: Int, dropAfter: Int?) {
        self.moraCount = moraCount
        self.dropAfter = dropAfter
    }

    public var accentType: AccentType {
        guard let drop = dropAfter else { return .heiban }
        if drop == 1 { return .atamadaka }
        if drop == moraCount { return .odaka }
        return .nakadaka
    }

    /// Whether mora `index` (0-based) is pronounced high.
    public func isHigh(_ index: Int) -> Bool {
        guard index >= 0, index < moraCount else { return false }
        switch accentType {
        case .heiban: return moraCount == 1 || index >= 1
        case .atamadaka: return index == 0
        case .nakadaka, .odaka: return index >= 1 && index < (dropAfter ?? 0)
        }
    }

    private static let small: Set<Character> = ["ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ゎ", "ャ", "ュ", "ョ", "ァ", "ィ", "ゥ", "ェ", "ォ", "ヮ"]

    private static func isKana(_ c: Character) -> Bool {
        guard let v = c.unicodeScalars.first?.value else { return false }
        return (0x3041...0x3096).contains(v) || (0x30A1...0x30FA).contains(v) || c == "ー"
    }

    /// First alternative, without parenthetical notes.
    private static func firstAlternative(_ s: String) -> String {
        var depth = 0
        var out = ""
        for ch in s {
            if "(（".contains(ch) { depth += 1; continue }
            if ")）".contains(ch) { depth = max(0, depth - 1); continue }
            if depth == 0 { out.append(ch) }
        }
        let first = out.split(separator: "／", omittingEmptySubsequences: false).first.map(String.init) ?? out
        return first
    }

    /// Splits a kana string into morae (small kana attach to the previous mora; `っ` and `ー` count).
    /// Characters that are not kana or `ー` (spaces, `～`, punctuation, `↓`, `○`) are ignored.
    public static func morae(of reading: String) -> [String] {
        var result: [String] = []
        for ch in firstAlternative(reading) where isKana(ch) {
            if small.contains(ch), !result.isEmpty {
                result[result.count - 1].append(ch)
            } else {
                result.append(String(ch))
            }
        }
        return result
    }

    /// Returns `nil` when the mora count of the pitch string differs from that of the reading.
    public static func parse(pitch: String, reading: String) -> PitchPattern? {
        let p = firstAlternative(pitch)
        guard !p.isEmpty else { return nil }
        var before = ""
        var drop: Int?
        for ch in p {
            if ch == "↓" {
                if drop == nil { drop = morae(of: before).count }
            } else {
                before.append(ch)
            }
        }
        let count = morae(of: before).count
        guard count > 0, count == morae(of: reading).count else { return nil }
        if let d = drop, d < 1 || d > count { return nil }
        return PitchPattern(moraCount: count, dropAfter: drop)
    }
}
