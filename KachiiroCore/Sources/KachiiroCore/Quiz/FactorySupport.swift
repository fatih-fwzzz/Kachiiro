import Foundation

/// Shared helpers for question factories.
enum FactorySupport {
    static func isPlainJapanese(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.unicodeScalars.allSatisfy { u in
            let v = u.value
            return (0x3041...0x3096).contains(v) || (0x30A1...0x30FA).contains(v) || v == 0x30FC
                || (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || v == 0x3005
        }
    }

    static func words(_ seed: SeedData, _ scope: StudyScope, where filter: (Word) -> Bool) -> [Word] {
        seed.words.filter { scope.contains(level: $0.level, lesson: $0.lesson) && filter($0) }
    }

    /// Verbs, i-/na-adjectives and nouns written only in kana/kanji (no `～`, digits, Latin, punctuation).
    static func inflectable(_ word: Word) -> Bool {
        Lexeme(word: word) != nil && isPlainJapanese(word.headword) && isPlainJapanese(word.reading)
    }

    static func shuffledChoices(correct: String, distractors: [String], rng: inout some RandomNumberGenerator) -> [String] {
        ([correct] + distractors).shuffled(using: &rng)
    }

    static func stableRNG(_ key: ItemKey) -> SeededRandomNumberGenerator {
        SeededRandomNumberGenerator(seed: key.stableSeed)
    }
}
