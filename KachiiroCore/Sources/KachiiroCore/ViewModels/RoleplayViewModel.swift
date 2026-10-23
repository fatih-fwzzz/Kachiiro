import Foundation
import Observation

@MainActor
@Observable
public final class RoleplayViewModel {
    public enum Speaker: Sendable { case partner, user }

    public enum Verdict: Equatable, Sendable {
        case passed(note: String)
        case failed(modelAnswer: String, note: String)
    }

    public struct Line: Identifiable, Equatable, Sendable {
        public let id: Int
        public let speaker: Speaker
        public let text: String
        public var verdict: Verdict?
    }

    public enum Mode {
        case scripted
    }

    public let scenario: RoleplayScenario
    public private(set) var lines: [Line] = []
    public private(set) var isFinished = false
    public private(set) var isWaiting = false
    public private(set) var errorMessage: String?

    private let mode: Mode
    private let speech: SpeechPlaying?
    private var currentTurnId: String?

    public init(scenario: RoleplayScenario, mode: Mode = .scripted, speech: SpeechPlaying? = nil) {
        self.scenario = scenario
        self.mode = mode
        self.speech = speech
    }

    private var currentTurn: RoleplayTurn? { currentTurnId.flatMap(scenario.turn) }

    /// The English intent of the learner's next reply.
    public var currentHint: String? { isFinished ? nil : currentTurn?.hint }
    /// The model reply for the current turn.
    public var modelAnswer: String? { isFinished ? nil : currentTurn?.replies.first?.accepted.first }

    public var userTurnCount: Int { lines.filter { $0.speaker == .user }.count }
    public var passedCount: Int {
        lines.filter {
            if case .passed? = $0.verdict { return true }
            return false
        }.count
    }

    public func start() {
        lines = []
        isFinished = false
        isWaiting = false
        errorMessage = nil
        currentTurnId = scenario.start
        if let turn = currentTurn { append(.partner, turn.partner) }
    }

    public func submit(_ text: String) async {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !isFinished, !isWaiting, let turn = currentTurn,
              let fallback = turn.replies.first else { return }
        errorMessage = nil
        let matched = turn.replies.first {
            TypingValidator.isCorrect(input, accepted: $0.accepted, keyPhrases: $0.keyPhrases)
        }
        if let matched {
            append(.user, input, verdict: .passed(note: matched.note))
            advance(to: matched.next)
        } else {
            append(.user, input, verdict: .failed(modelAnswer: fallback.accepted[0], note: fallback.note))
            advance(to: fallback.next)
        }
    }

    public func replay(_ line: Line) {
        guard line.speaker == .partner else { return }
        speech?.speak(line.text, slow: false)
    }

    private func advance(to next: String?) {
        if let next, let turn = scenario.turn(next) {
            currentTurnId = next
            append(.partner, turn.partner)
        } else {
            currentTurnId = nil
            append(.partner, scenario.closing)
            isFinished = true
        }
    }

    private func append(_ speaker: Speaker, _ text: String, verdict: Verdict? = nil) {
        lines.append(Line(id: lines.count, speaker: speaker, text: text, verdict: verdict))
        if speaker == .partner { speech?.speak(text, slow: false) }
    }
}
