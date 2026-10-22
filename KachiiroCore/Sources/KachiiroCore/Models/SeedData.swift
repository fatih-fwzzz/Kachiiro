import Foundation

public struct SeedData: Codable, Sendable {
    public let words: [Word]
    public let patterns: [GrammarPattern]
    public let kanji: [KanjiEntry]

    public init(words: [Word], patterns: [GrammarPattern], kanji: [KanjiEntry]) {
        self.words = words
        self.patterns = patterns
        self.kanji = kanji
    }

    public static func load(from data: Data) throws -> SeedData {
        try JSONDecoder().decode(SeedData.self, from: data)
    }

    public func word(id: Int) -> Word? { words.first { $0.id == id } }
    public func pattern(id: Int) -> GrammarPattern? { patterns.first { $0.id == id } }
    public func kanjiEntry(id: Int) -> KanjiEntry? { kanji.first { $0.id == id } }
}
