import Foundation

public struct DiffSegment: Equatable, Sendable {
    public enum Kind: Sendable { case match, missing, extra }
    public let kind: Kind
    public let text: String
}

public struct ShadowingResult: Equatable, Sendable {
    public static let passScore = 0.8

    public let segments: [DiffSegment]
    public let score: Double
    public let passed: Bool
}

public enum TextDiff {
    /// Character-level LCS diff of the normalized strings (punctuation, spaces and kana script ignored).
    public static func diff(expected: String, actual: String) -> [DiffSegment] {
        let a = Array(TypingValidator.normalize(expected))
        let b = Array(TypingValidator.normalize(actual))
        let n = a.count, m = b.count
        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: 1, through: n, by: 1) {
            for j in stride(from: 1, through: m, by: 1) {
                dp[i][j] = a[i - 1] == b[j - 1] ? dp[i - 1][j - 1] + 1 : max(dp[i - 1][j], dp[i][j - 1])
            }
        }

        var reversed: [(DiffSegment.Kind, Character)] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            if i > 0, j > 0, a[i - 1] == b[j - 1] {
                reversed.append((.match, a[i - 1]))
                i -= 1
                j -= 1
            } else if i > 0, j == 0 || dp[i - 1][j] >= dp[i][j - 1] {
                reversed.append((.missing, a[i - 1]))
                i -= 1
            } else {
                reversed.append((.extra, b[j - 1]))
                j -= 1
            }
        }

        var segments: [DiffSegment] = []
        for (kind, char) in reversed.reversed() {
            if let last = segments.last, last.kind == kind {
                segments[segments.count - 1] = DiffSegment(kind: kind, text: last.text + String(char))
            } else {
                segments.append(DiffSegment(kind: kind, text: String(char)))
            }
        }
        return segments
    }

    public static func result(expected: String, actual: String) -> ShadowingResult {
        let segments = diff(expected: expected, actual: actual)
        let expectedCount = TypingValidator.normalize(expected).count
        let matched = segments.filter { $0.kind == .match }.reduce(0) { $0 + $1.text.count }
        let score = expectedCount == 0 ? 0 : Double(matched) / Double(expectedCount)
        return ShadowingResult(segments: segments, score: score, passed: score >= ShadowingResult.passScore)
    }
}

public extension ShadowingLine {
    /// Polite and keigo set phrases from the Irodori vocabulary, with their pitch.
    static func irodori(seed: SeedData) -> [ShadowingLine] {
        let markers = ["ございま", "いらっしゃ", "いただ", "おります", "申し", "伺", "参り", "くださ"]
        return seed.words.compactMap { word in
            guard word.pos == .expression, !word.headword.contains("～"),
                  word.meaning.contains("polite expression") || markers.contains(where: word.headword.contains)
            else { return nil }
            return ShadowingLine(
                id: "i\(word.id)", text: word.headword, reading: word.reading, meaning: word.meaning,
                pitch: PitchPattern.parse(pitch: word.pitch, reading: word.reading)
            )
        }
    }

    /// Bundled business phrases followed by the Irodori ones.
    static func bundledLines(content: KeigoContent = .bundled, seed: SeedData) -> [ShadowingLine] {
        content.shadowing + irodori(seed: seed)
    }
}
