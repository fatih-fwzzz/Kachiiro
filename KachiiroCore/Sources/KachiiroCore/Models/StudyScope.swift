/// Which part of the syllabus drills draw from.
public struct StudyScope: Codable, Equatable, Sendable {
    public var levels: Set<Level>
    public var lessonRange: ClosedRange<Int>?

    public init(levels: Set<Level> = Set(Level.allCases), lessonRange: ClosedRange<Int>? = nil) {
        self.levels = levels
        self.lessonRange = lessonRange
    }

    public static let all = StudyScope()

    /// Short label: the books in syllabus order, then the lesson range ("初級1 · L1–9", "All books").
    public var label: String {
        let books = levels.count == Level.allCases.count
            ? "All books"
            : Level.allCases.filter(levels.contains).map(\.bookName).joined(separator: " + ")
        guard let lessonRange else { return books }
        let lessons = lessonRange.count == 1 ? "L\(lessonRange.lowerBound)" : "L\(lessonRange.lowerBound)–\(lessonRange.upperBound)"
        return "\(books) · \(lessons)"
    }

    public func contains(level: Level, lesson: Int) -> Bool {
        guard levels.contains(level) else { return false }
        guard let lessonRange else { return true }
        return lessonRange.contains(lesson)
    }
}
