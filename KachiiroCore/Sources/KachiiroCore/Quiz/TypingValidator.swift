import Foundation

public enum TypingValidator {
    private static let trailingPunctuation: Set<Character> = ["。", ".", "!", "?", "．", "！", "？"]

    /// NFKC, trim (including U+3000), drop trailing sentence punctuation and inner spaces,
    /// fold katakana to hiragana (keeping `ー`), lowercase ASCII.
    public static func normalize(_ text: String) -> String {
        var s = text.precomposedStringWithCompatibilityMapping
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = s.last, trailingPunctuation.contains(last) { s.removeLast() }
        s.unicodeScalars.removeAll { CharacterSet.whitespacesAndNewlines.contains($0) }
        var folded = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            if (0x30A1...0x30F6).contains(u.value), let h = Unicode.Scalar(u.value - 0x60) {
                folded.append(h)
            } else {
                folded.append(u)
            }
        }
        return String(folded).lowercased()
    }

    public static func isCorrect(_ input: String, accepted: [String]) -> Bool {
        let n = normalize(input)
        guard !n.isEmpty else { return false }
        return accepted.contains { normalize($0) == n }
    }
}
