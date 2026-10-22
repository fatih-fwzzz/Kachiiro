import Foundation

public struct ReviewState: Codable, Equatable, Sendable {
    public var key: ItemKey
    /// Leitner box 0…5.
    public var box: Int
    public var lapses: Int
    public var correctCount: Int
    public var wrongCount: Int
    public var lastAnswered: Date
    public var dueDate: Date
    public var isBookmarked: Bool

    public init(
        key: ItemKey, box: Int = 0, lapses: Int = 0, correctCount: Int = 0, wrongCount: Int = 0,
        lastAnswered: Date, dueDate: Date, isBookmarked: Bool = false
    ) {
        self.key = key
        self.box = box
        self.lapses = lapses
        self.correctCount = correctCount
        self.wrongCount = wrongCount
        self.lastAnswered = lastAnswered
        self.dueDate = dueDate
        self.isBookmarked = isBookmarked
    }

    /// Weak = recently failed and still in the low boxes, or bookmarked.
    public var isWeak: Bool { (box <= 1 && wrongCount > 0) || isBookmarked }
}
