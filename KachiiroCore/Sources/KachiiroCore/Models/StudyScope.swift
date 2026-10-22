/// Which part of the syllabus drills draw from.
public struct StudyScope: Codable, Equatable, Sendable {
    public var levels: Set<Level>
    public var lessonRange: ClosedRange<Int>?

    public init(levels: Set<Level> = Set(Level.allCases), lessonRange: ClosedRange<Int>? = nil) {
        self.levels = levels
        self.lessonRange = lessonRange
    }

    public static let all = StudyScope()

    public func contains(level: Level, lesson: Int) -> Bool {
        guard levels.contains(level) else { return false }
        guard let lessonRange else { return true }
        return lessonRange.contains(lesson)
    }
}
