public struct Word: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let headword: String
    public let reading: String
    public let pitch: String
    public let meaning: String
    public let pos: PartOfSpeech
    public let contextNote: String
    public let alternates: [String]
    public let level: Level
    public let lesson: Int
    public let activity: Int
    public let topicTag: String

    public init(
        id: Int, headword: String, reading: String, pitch: String = "", meaning: String = "",
        pos: PartOfSpeech, contextNote: String = "", alternates: [String] = [],
        level: Level = .a1, lesson: Int = 1, activity: Int = 1, topicTag: String = ""
    ) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.pitch = pitch
        self.meaning = meaning
        self.pos = pos
        self.contextNote = contextNote
        self.alternates = alternates
        self.level = level
        self.lesson = lesson
        self.activity = activity
        self.topicTag = topicTag
    }
}
