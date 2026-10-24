import Foundation

/// Hiragana readings computed on the device instead of trusting a language model, which often misreads kanji.
/// The system tokenizer reads each word; the course word list corrects words it knows; a few common
/// tokenizer misreads are overridden. Kana and punctuation are kept exactly as written.
public struct JapaneseReading: Sendable {
    /// Words the tokenizer reads wrongly in business Japanese.
    static let overrides: [String: String] = [
        "日本人": "にほんじん", "日本語": "にほんご", "日本": "にほん", "今席": "いませき",
    ]

    private let known: [String: String]

    /// - Parameter words: course words; headwords that contain kanji become known readings.
    public init(words: [Word] = []) {
        var known: [String: String] = [:]
        for word in words where word.headword.unicodeScalars.contains(where: Self.isKanji) {
            known[word.headword] = known[word.headword] ?? word.reading
        }
        self.known = known
    }

    public func hiragana(for text: String) -> String {
        let ns = text as NSString
        let tokenizer = CFStringTokenizerCreate(
            nil, text as CFString, CFRange(location: 0, length: ns.length),
            kCFStringTokenizerUnitWordBoundary, Locale(identifier: "ja") as CFLocale
        )
        var tokens: [(range: NSRange, text: String, latin: String?)] = []
        while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
            let r = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let range = NSRange(location: r.location, length: r.length)
            let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
            tokens.append((range, ns.substring(with: range), latin))
        }
        var out = ""
        var cursor = 0
        var i = 0
        while i < tokens.count {
            let start = tokens[i].range.location
            if start > cursor { out += ns.substring(with: NSRange(location: cursor, length: start - cursor)) }
            // The tokenizer splits words like 日本|人; the longest known word over up to three tokens wins.
            var matched = false
            for length in stride(from: min(3, tokens.count - i), through: 1, by: -1) {
                let last = tokens[i + length - 1].range
                let span = NSRange(location: start, length: last.location + last.length - start)
                let word = ns.substring(with: span)
                if word.unicodeScalars.contains(where: Self.isKanji), let fixed = Self.overrides[word] ?? known[word] {
                    out += fixed
                    cursor = span.location + span.length
                    i += length
                    matched = true
                    break
                }
            }
            if matched { continue }
            out += Self.transcribe(tokens[i].text, latin: tokens[i].latin)
            cursor = tokens[i].range.location + tokens[i].range.length
            i += 1
        }
        if cursor < ns.length { out += ns.substring(from: cursor) }
        return out
    }

    private static func transcribe(_ token: String, latin: String?) -> String {
        guard token.unicodeScalars.contains(where: isKanji), let latin,
              let hiragana = latin.applyingTransform(.latinToHiragana, reverse: false),
              hiragana.unicodeScalars.allSatisfy(isKana) else { return token }
        return hiragana
    }

    static func isKanji(_ s: Unicode.Scalar) -> Bool { (0x4E00...0x9FFF).contains(s.value) || s.value == 0x3005 }
    static func isKana(_ s: Unicode.Scalar) -> Bool { (0x3040...0x30FF).contains(s.value) }

    /// Japanese text with no Latin letters: rejects instruction labels or English the model put in place of an answer.
    public static func isJapaneseSentence(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        return scalars.contains(where: { isKana($0) || isKanji($0) })
            && !scalars.contains(where: { ("a"..."z").contains(Character($0)) || ("A"..."Z").contains(Character($0)) })
    }
}
