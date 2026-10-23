import Foundation
import Observation

@MainActor
@Observable
public final class QuizSessionViewModel {
    public enum AnswerResult: Equatable, Sendable {
        case correct
        case wrong(correctAnswer: String)
    }

    public struct Answer: Equatable, Sendable {
        public let key: ItemKey
        public let correct: Bool
    }

    public let questions: [QuizQuestion]
    public private(set) var index = 0
    /// The mode the user asked for; see `activeMode` for what the current question supports.
    public private(set) var mode: InputMode
    public private(set) var result: AnswerResult?
    public private(set) var answers: [Answer] = []
    public private(set) var isFinished = false
    public private(set) var bookmarkedKeys: Set<ItemKey> = []

    private let repository: ProgressRepository
    private let speech: SpeechPlaying?
    private let now: () -> Date

    public init(
        questions: [QuizQuestion],
        initialMode: InputMode,
        repository: ProgressRepository,
        speech: SpeechPlaying? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        self.questions = questions
        self.mode = initialMode
        self.repository = repository
        self.speech = speech
        self.now = now
        self.isFinished = questions.isEmpty
        bookmarkedKeys = Set(questions.map(\.id).filter { repository.reviewState($0)?.isBookmarked == true })
    }

    public var currentQuestion: QuizQuestion? {
        questions.indices.contains(index) && !isFinished ? questions[index] : nil
    }

    /// `mode` when the current question supports it, otherwise the mode it does support.
    public var activeMode: InputMode {
        guard let q = currentQuestion, !q.supportedModes.contains(mode) else { return mode }
        return q.supportedModes.contains(.choice) ? .choice : .typing
    }

    public var canType: Bool { currentQuestion?.supportedModes.contains(.typing) ?? false }
    public var canChoose: Bool { currentQuestion?.supportedModes.contains(.choice) ?? false }
    public var hasSpeech: Bool { speech != nil && currentQuestion?.speech != nil }
    /// The question has audio but the device has no Japanese voice installed.
    public var speechUnavailable: Bool { hasSpeech && speech?.hasVoice == false }
    public static let missingVoiceMessage = "Install a Japanese voice in Settings > Accessibility > Spoken Content"
    public var isCurrentBookmarked: Bool { currentQuestion.map { bookmarkedKeys.contains($0.id) } ?? false }
    public var total: Int { questions.count }
    public var score: Int { answers.filter(\.correct).count }

    public var wrongQuestions: [QuizQuestion] {
        let wrong = Set(answers.filter { !$0.correct }.map(\.key))
        return questions.filter { wrong.contains($0.id) }
    }

    /// Ignored when the current question does not support `newMode`; the question never changes.
    public func setMode(_ newMode: InputMode) {
        guard let q = currentQuestion, q.supportedModes.contains(newMode) else { return }
        mode = newMode
    }

    public func submitChoice(_ choice: String) {
        guard let q = currentQuestion, result == nil, q.supportedModes.contains(.choice) else { return }
        finishAnswer(q, correct: choice == q.correctChoice, mode: .choice)
    }

    public func submitText(_ text: String) {
        guard let q = currentQuestion, result == nil, q.supportedModes.contains(.typing),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let correct = TypingValidator.isCorrect(text, accepted: q.acceptedAnswers, keyPhrases: q.keyPhrases)
        finishAnswer(q, correct: correct, mode: .typing)
    }

    public func next() {
        guard result != nil, !isFinished else { return }
        result = nil
        if index + 1 >= questions.count {
            isFinished = true
        } else {
            index += 1
        }
    }

    public func playPrompt(slow: Bool = false) {
        guard let text = currentQuestion?.speech else { return }
        speech?.speak(text, slow: slow)
    }

    public func toggleBookmark() {
        guard let key = currentQuestion?.id else { return }
        let on = !bookmarkedKeys.contains(key)
        repository.setBookmark(key, on)
        if on { bookmarkedKeys.insert(key) } else { bookmarkedKeys.remove(key) }
    }

    /// A fresh session over the questions answered wrongly, or `nil` when there were none.
    public func makeRetrySession() -> QuizSessionViewModel? {
        let wrong = wrongQuestions
        guard !wrong.isEmpty else { return nil }
        return QuizSessionViewModel(questions: wrong, initialMode: mode, repository: repository, speech: speech, now: now)
    }

    private func finishAnswer(_ q: QuizQuestion, correct: Bool, mode used: InputMode) {
        result = correct ? .correct : .wrong(correctAnswer: q.correctChoice)
        answers.append(Answer(key: q.id, correct: correct))
        repository.record(q.id, pillar: q.pillar, correct: correct, mode: used, at: now())
    }
}
