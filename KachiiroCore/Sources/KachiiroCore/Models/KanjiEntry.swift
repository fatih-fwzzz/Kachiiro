public struct KanjiEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let kanjiNumber: Int
    public let isFirstAppearance: Bool
    public let kanji: String
    public let reading: String
    public let word: String
    public let wordReading: String
    public let level: Level
    public let lesson: Int

    public init(
        id: Int, kanjiNumber: Int, isFirstAppearance: Bool, kanji: String, reading: String,
        word: String, wordReading: String, level: Level, lesson: Int
    ) {
        self.id = id
        self.kanjiNumber = kanjiNumber
        self.isFirstAppearance = isFirstAppearance
        self.kanji = kanji
        self.reading = reading
        self.word = word
        self.wordReading = wordReading
        self.level = level
        self.lesson = lesson
    }
}
