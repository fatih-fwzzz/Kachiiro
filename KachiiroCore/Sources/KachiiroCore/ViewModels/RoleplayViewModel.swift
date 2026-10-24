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
        /// Gemini Live speaks the partner; the reviewer checks each learner line.
        case live(partner: LiveRoleplayPartner, reviewer: KaiwaAIService, audio: LiveAudioIO)
    }

    public let scenario: RoleplayScenario
    public private(set) var lines: [Line] = []
    public private(set) var isFinished = false
    public private(set) var isWaiting = false
    public private(set) var errorMessage: String?
    /// `true` after a free-mode request failed and `retryLast()` can re-send it.
    public private(set) var canRetry = false
    /// The in-flight review of the learner's latest live line; exposed so tests can await it.
    public private(set) var pendingReview: Task<Void, Never>?

    public enum LiveStatus: Equatable, Sendable { case idle, connecting, listening, partnerSpeaking }
    public private(set) var liveStatus: LiveStatus = .idle
    /// Learner speech transcribed so far, not yet a line.
    public private(set) var liveUserDraft = ""
    /// Partner speech transcribed so far, not yet a line.
    public private(set) var livePartnerDraft = ""
    public private(set) var isMicrophoneOn = false
    /// The running session's event loop; exposed so tests can await it.
    public private(set) var liveSession: Task<Void, Never>?

    private let mode: Mode
    private let speech: SpeechPlaying?
    private var currentTurnId: String?

    public init(scenario: RoleplayScenario, mode: Mode = .scripted(judge: nil), speech: SpeechPlaying? = nil) {
        self.scenario = scenario
        self.mode = mode
        self.speech = speech
    }

    public var isFreeMode: Bool {
        switch mode {
        case .free, .live: true
        case .scripted: false
        }
    }

    public var isLiveMode: Bool {
        if case .live = mode { return true }
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
        case .live:
            end()
            liveUserDraft = ""
            livePartnerDraft = ""
            currentTurnId = nil
            pendingReview = nil
            await connectLive()
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
        case .live(let partner, let reviewer, _):
            guard !canRetry, liveSession != nil else { return }
            append(.user, input)
            reviewLiveLine(reviewer, input: input)
            partner.sendText(input)
        }
    }

    /// Re-sends the last free-mode or live request after a failure.
    public func retryLast() async {
        guard canRetry, !isWaiting else { return }
        switch mode {
        case .free(let service):
            errorMessage = nil
            await requestPartnerTurn(service)
        case .live:
            errorMessage = nil
            await connectLive()
        case .scripted:
            return
        }
    }

    /// Releases the live connection and stops the call audio; a no-op outside live mode.
    public func end() {
        guard case .live(let partner, _, let audio) = mode else { return }
        pendingReview?.cancel()
        let session = liveSession
        liveSession = nil
        session?.cancel()
        partner.close()
        audio.stop()
        isMicrophoneOn = false
        liveStatus = .idle
    }

    /// Ends the call; pending drafts are dropped.
    public func hangUp() {
        guard isLiveMode, !isFinished else { return }
        isFinished = true
        end()
    }

    public func replay(_ line: Line) {
        guard line.speaker == .partner, !isLiveMode else { return }
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

    // MARK: Live

    private func connectLive() async {
        guard case .live(let partner, _, let audio) = mode else { return }
        isWaiting = true
        canRetry = false
        liveStatus = .connecting
        defer { isWaiting = false }
        let events: AsyncThrowingStream<LiveEvent, Error>
        do {
            events = try await partner.connect(system: KaiwaPrompts.livePartner(scenario), history: lines)
        } catch {
            errorMessage = error.localizedDescription
            canRetry = true
            liveStatus = .idle
            return
        }
        liveStatus = .listening
        liveSession = Task {
            do {
                for try await event in events { self.handleLive(event) }
                guard !Task.isCancelled else { return }
                self.liveSessionEnded(nil)
            } catch {
                guard !Task.isCancelled else { return }
                self.liveSessionEnded(error)
            }
        }
        do {
            try await audio.start { [weak partner] chunk in partner?.sendAudio(chunk) }
            isMicrophoneOn = true
        } catch {
            isMicrophoneOn = false
            errorMessage = error.localizedDescription
        }
    }

    func handleLive(_ event: LiveEvent) {
        guard case .live(_, _, let audio) = mode else { return }
        switch event {
        case .audio(let data):
            audio.play(data)
            liveStatus = .partnerSpeaking
        case .transcript(let piece):
            livePartnerDraft += piece
            liveStatus = .partnerSpeaking
        case .inputTranscript(let piece):
            liveUserDraft += piece
        case .interrupted:
            audio.flushPlayback()
            commitLiveTurn()
            liveStatus = .listening
        case .turnComplete:
            commitLiveTurn()
            liveStatus = .listening
            if userTurnCount >= Self.maxFreeTurns {
                isFinished = true
                end()
            }
        case .setupComplete, .other:
            break
        }
    }

    /// Commits the drafts as lines once the partner actually spoke, so a pause never splits the learner's sentence.
    private func commitLiveTurn() {
        guard case .live(_, let reviewer, _) = mode else { return }
        let partnerText = livePartnerDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !partnerText.isEmpty else { return }
        let userText = liveUserDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userText.isEmpty {
            append(.user, userText)
            reviewLiveLine(reviewer, input: userText)
        }
        append(.partner, partnerText, speak: false)
        liveUserDraft = ""
        livePartnerDraft = ""
    }

    private func liveSessionEnded(_ error: Error?) {
        guard case .live(_, _, let audio) = mode else { return }
        audio.stop()
        isMicrophoneOn = false
        liveStatus = .idle
        liveSession = nil
        if !isFinished {
            errorMessage = error?.localizedDescription ?? "The live session ended."
            canRetry = true
        }
    }

    private func reviewLiveLine(_ reviewer: KaiwaAIService, input: String) {
        let index = lines.count - 1
        let history = lines
        pendingReview = Task { [scenario] in
            guard let judgement = try? await reviewer.reviewRoleplayLine(scenario: scenario, history: history) else {
                return
            }
            guard index < self.lines.count, self.lines[index].speaker == .user, self.lines[index].text == input else {
                return
            }
            self.lines[index].verdict = .reviewed(
                acceptable: judgement.acceptable, corrected: judgement.corrected, explanation: judgement.explanation
            )
        }
    }

    private func append(_ speaker: Speaker, _ text: String, verdict: Verdict? = nil, speak: Bool = true) {
        lines.append(Line(id: lines.count, speaker: speaker, text: text, verdict: verdict))
        if speaker == .partner, speak { speech?.speak(text, slow: false) }
    }
}
