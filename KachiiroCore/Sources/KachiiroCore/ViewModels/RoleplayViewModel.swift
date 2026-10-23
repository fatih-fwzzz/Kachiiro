import Foundation
import Observation

@MainActor
@Observable
public final class RoleplayViewModel {
    public static let maxFreeTurns = 8

    public enum Speaker: Sendable { case partner, user }

    public enum Verdict: Equatable, Sendable {
        case passed(note: String)
        case failed(modelAnswer: String, note: String)
        case reviewed(acceptable: Bool, corrected: String, explanation: String)
    }

    public struct Line: Identifiable, Equatable, Sendable {
        public let id: Int
        public let speaker: Speaker
        public let text: String
        public var verdict: Verdict?
    }

    public enum Mode {
        /// Fixed branching script; `judge` reviews replies the script does not recognise.
        case scripted(judge: AnswerJudging?)
        /// The AI plays the partner and reviews every reply.
        case free(KaiwaAIService)
    }

    public let scenario: RoleplayScenario
    public private(set) var lines: [Line] = []
    public private(set) var isFinished = false
    public private(set) var isWaiting = false
    public private(set) var errorMessage: String?
    /// `true` after a free-mode request failed and `retryLast()` can re-send it.
    public private(set) var canRetry = false

    private let mode: Mode
    private let speech: SpeechPlaying?
    private var currentTurnId: String?

    public init(scenario: RoleplayScenario, mode: Mode = .scripted(judge: nil), speech: SpeechPlaying? = nil) {
        self.scenario = scenario
        self.mode = mode
        self.speech = speech
    }

    public var isFreeMode: Bool {
        if case .free = mode { return true }
        return false
    }

    private var currentTurn: RoleplayTurn? { currentTurnId.flatMap(scenario.turn) }

    /// The English intent of the learner's next reply; in free mode, the scenario goal.
    public var currentHint: String? {
        guard !isFinished else { return nil }
        return isFreeMode ? scenario.goal : currentTurn?.hint
    }

    /// The model reply for the current turn (scripted mode only).
    public var modelAnswer: String? {
        guard !isFinished, !isFreeMode else { return nil }
        return currentTurn?.replies.first?.accepted.first
    }

    public var userTurnCount: Int { lines.filter { $0.speaker == .user }.count }
    public var passedCount: Int {
        lines.filter {
            switch $0.verdict {
            case .passed?, .reviewed(true, _, _)?: true
            default: false
            }
        }.count
    }

    public func start() async {
        lines = []
        isFinished = false
        isWaiting = false
        errorMessage = nil
        canRetry = false
        switch mode {
        case .scripted:
            currentTurnId = scenario.start
            if let turn = currentTurn { append(.partner, turn.partner) }
        case .free(let service):
            currentTurnId = nil
            await requestPartnerTurn(service)
        }
    }

    public func submit(_ text: String) async {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !isFinished, !isWaiting else { return }
        errorMessage = nil
        switch mode {
        case .scripted(let judge):
            await submitScripted(input, judge: judge)
        case .free(let service):
            guard !canRetry else { return }
            append(.user, input)
            await requestPartnerTurn(service)
        }
    }

    /// Re-sends the last free-mode request after a failure.
    public func retryLast() async {
        guard canRetry, !isWaiting, case .free(let service) = mode else { return }
        errorMessage = nil
        await requestPartnerTurn(service)
    }

    public func replay(_ line: Line) {
        guard line.speaker == .partner else { return }
        speech?.speak(line.text, slow: false)
    }

    // MARK: Scripted

    private func submitScripted(_ input: String, judge: AnswerJudging?) async {
        guard let turn = currentTurn, let fallback = turn.replies.first else { return }
        let matched = turn.replies.first {
            TypingValidator.isCorrect(input, accepted: $0.accepted, keyPhrases: $0.keyPhrases)
        }
        if let matched {
            append(.user, input, verdict: .passed(note: matched.note))
            advance(to: matched.next)
            return
        }
        guard let judge else {
            append(.user, input, verdict: .failed(modelAnswer: fallback.accepted[0], note: fallback.note))
            advance(to: fallback.next)
            return
        }

        append(.user, input)
        let lineIndex = lines.count - 1
        isWaiting = true
        let verdict: Verdict
        do {
            let judgement = try await judge.judge(answer: input, question: judgingQuestion(for: turn))
            verdict = .reviewed(acceptable: judgement.acceptable, corrected: judgement.corrected, explanation: judgement.explanation)
        } catch {
            errorMessage = "AI check failed: \(error.localizedDescription)"
            verdict = .failed(modelAnswer: fallback.accepted[0], note: fallback.note)
        }
        isWaiting = false
        lines[lineIndex].verdict = verdict
        advance(to: fallback.next)
    }

    private func judgingQuestion(for turn: RoleplayTurn) -> QuizQuestion {
        let models = turn.replies.flatMap(\.accepted)
        return QuizQuestion(
            id: .generated(.keigo), drill: .keigo, promptTitle: scenario.title, promptBody: turn.partner,
            choices: [], correctChoice: turn.replies[0].accepted[0], acceptedAnswers: models,
            supportedModes: [.typing],
            judgingContext: "Roleplay: \(scenario.setting) The learner (\(scenario.userRole)) must: \(turn.hint). Partner said: \(turn.partner)"
        )
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

    // MARK: Free

    private func requestPartnerTurn(_ service: KaiwaAIService) async {
        isWaiting = true
        canRetry = false
        defer { isWaiting = false }
        do {
            let turn = try await service.partnerTurn(scenario: scenario, history: lines)
            if let last = lines.indices.last, lines[last].speaker == .user {
                lines[last].verdict = .reviewed(
                    acceptable: turn.feedback.acceptable, corrected: turn.feedback.corrected,
                    explanation: turn.feedback.explanation
                )
            }
            append(.partner, turn.partnerLine)
            if turn.finished || userTurnCount >= Self.maxFreeTurns { isFinished = true }
        } catch {
            errorMessage = error.localizedDescription
            canRetry = true
        }
    }

    private func append(_ speaker: Speaker, _ text: String, verdict: Verdict? = nil) {
        lines.append(Line(id: lines.count, speaker: speaker, text: text, verdict: verdict))
        if speaker == .partner { speech?.speak(text, slow: false) }
    }
}
