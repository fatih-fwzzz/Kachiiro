public struct GrammarPattern: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let level: Level
    public let lesson: Int
    public let lessonTitle: String
    public let topic: String
    public let pattern: String
    public let example: String

    public init(id: Int, level: Level, lesson: Int, lessonTitle: String, topic: String, pattern: String, example: String) {
        self.id = id
        self.level = level
        self.lesson = lesson
        self.lessonTitle = lessonTitle
        self.topic = topic
        self.pattern = pattern
        self.example = example
    }
}
