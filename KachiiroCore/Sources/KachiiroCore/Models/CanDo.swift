import Foundation

/// One Can-do statement of the course tables of contents.
public struct CanDo: Codable, Sendable, Equatable, Identifiable {
    /// Number printed in the book (1…69 for 初級1, 1…78 for 初級2).
    public let id: Int
    public let book: String
    public let level: Level
    public let lesson: Int
    public let lessonTitle: String
    public let topic: String
    public let text: String

    public static let book1 = "初級1"
    public static let book2 = "初級2"

    /// Unique across books: 初級1 ids stay 1…69, 初級2 ids become 1001…1078.
    public var storageId: Int { book == Self.book2 ? 1000 + id : id }

    public var hasAudio: Bool { book == Self.book2 }

    public static func load(from data: Data) throws -> [CanDo] {
        try JSONDecoder().decode([CanDo].self, from: data)
    }
}
