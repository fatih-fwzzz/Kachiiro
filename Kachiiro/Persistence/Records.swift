import Foundation
import SwiftData
import KachiiroCore

@Model
final class ReviewRecord {
    @Attribute(.unique) var key: String
    var box: Int
    var lapses: Int
    var correctCount: Int
    var wrongCount: Int
    var lastAnswered: Date
    var dueDate: Date
    var isBookmarked: Bool

    init(state: ReviewState) {
        key = state.key.raw
        box = state.box
        lapses = state.lapses
        correctCount = state.correctCount
        wrongCount = state.wrongCount
        lastAnswered = state.lastAnswered
        dueDate = state.dueDate
        isBookmarked = state.isBookmarked
    }

    var state: ReviewState {
        ReviewState(
            key: ItemKey(key), box: box, lapses: lapses, correctCount: correctCount, wrongCount: wrongCount,
            lastAnswered: lastAnswered, dueDate: dueDate, isBookmarked: isBookmarked
        )
    }

    func apply(_ s: ReviewState) {
        box = s.box
        lapses = s.lapses
        correctCount = s.correctCount
        wrongCount = s.wrongCount
        lastAnswered = s.lastAnswered
        dueDate = s.dueDate
        isBookmarked = s.isBookmarked
    }
}

@Model
final class AttemptRecord {
    var key: String
    var pillar: String
    var correct: Bool
    var mode: String
    var date: Date

    init(key: String, pillar: String, correct: Bool, mode: String, date: Date) {
        self.key = key
        self.pillar = pillar
        self.correct = correct
        self.mode = mode
        self.date = date
    }
}

@Model
final class CanDoRecord {
    @Attribute(.unique) var id: Int

    init(id: Int) { self.id = id }
}
