import Foundation
import Observation

@MainActor
@Observable
public final class MockExamViewModel {
    public enum Phase: Equatable, Sendable { case notStarted, running, finished }

    public struct PillarScore: Identifiable, Equatable, Sendable {
        public var id: Pillar { pillar }
        public let pillar: Pillar
        public let correct: Int
        public let total: Int
    }

    public struct Result: Equatable, Sendable {
        public let total: Int
        public let correct: Int
        public let unanswered: Int
        public let duration: TimeInterval
        public let byPillar: [PillarScore]
        public let wrongQuestions: [QuizQuestion]
    }

    /// Questions per drill: Katsuyou 6, Goi 6, Bunpou 5, Choukai 3.
    public static let allocation: [(drill: DrillKind, count: Int)] = [
        (.verbForms, 3), (.inflectionMatrix, 3),
        (.vocab, 3), (.kanji, 2), (.pitch, 1),
        (.patternRecognition, 2), (.registerShift, 3),
        (.dictation, 3),
    ]
    public static let timeLimit: TimeInterval = 20 * 60
    public static var questionCount: Int { allocation.reduce(0) { $0 + $1.count } }

    public private(set) var phase: Phase = .notStarted
    public private(set) var questions: [QuizQuestion] = []
    public private(set) var index = 0
    public private(set) var mode: InputMode
    /// Shown on the start/exam screen when the study scope cannot fill the exam.
    public private(set) var note: String?
    public private(set) var result: Result?
    public private(set) var remaining: TimeInterval = MockExamViewModel.timeLimit

    private var answers: [ItemKey: (value: String, mode: InputMode)] = [:]
    private var startedAt: Date?
    private let seed: SeedData
    private let settings: SettingsStore
    private let repository: ProgressRepository
    private let speech: SpeechPlaying?
    private let factories: [any QuestionFactory]
    private let now: () -> Date
    private var rng: AnyRandomNumberGenerator

    public init(
        seed: SeedData, settings: SettingsStore, repository: ProgressRepository, speech: SpeechPlaying? = nil,
        factories: [any QuestionFactory] = QuestionFactoryRegistry.all,
        now: @escaping () -> Date = { Date() }, randomSeed: UInt64? = nil
    ) {
        self.seed = seed
        self.settings = settings
        self.repository = repository
        self.speech = speech
        self.factories = factories
        self.now = now
        self.mode = settings.inputMode
        self.rng = randomSeed.map { AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: $0)) }
            ?? AnyRandomNumberGenerator(SystemRandomNumberGenerator())
    }

    // MARK: State

    public var currentQuestion: QuizQuestion? {
        phase == .running && questions.indices.contains(index) ? questions[index] : nil
    }

    public var activeMode: InputMode {
        guard let q = currentQuestion, !q.supportedModes.contains(mode) else { return mode }
        return q.supportedModes.contains(.choice) ? .choice : .typing
    }

    public var canType: Bool { currentQuestion?.supportedModes.contains(.typing) ?? false }
    public var canChoose: Bool { currentQuestion?.supportedModes.contains(.choice) ?? false }
    public var hasSpeech: Bool { speech != nil && currentQuestion?.speech != nil }
    public var speechUnavailable: Bool { hasSpeech && speech?.hasVoice == false }
    public var answeredCount: Int { answers.count }
    public var isLastQuestion: Bool { index + 1 >= questions.count }

    /// The recorded answer text for the current question (to re-display the selection).
    public var currentAnswer: String? { currentQuestion.flatMap { answers[$0.id]?.value } }

    // MARK: Building the exam

    /// Builds the question set from the current study scope and starts the clock.
    public func start() {
        let scope = settings.scope
        let (built, detail) = buildQuestions(scope: scope)
        questions = built
        if built.count < Self.questionCount {
            note = "Only \(built.count) of \(Self.questionCount) questions are available in your study scope."
                + (detail.map { " \($0)" } ?? "")
        } else {
            note = detail
        }
        index = 0
        answers = [:]
        result = nil
        mode = settings.inputMode
        startedAt = now()
        remaining = Self.timeLimit
        phase = built.isEmpty ? .notStarted : .running
        if built.isEmpty { note = PracticeViewModel.emptyScopeMessage }
    }

    private func factory(_ drill: DrillKind) -> (any QuestionFactory)? {
        factories.first { $0.drill == drill }
    }

    private func buildQuestions(scope: StudyScope) -> ([QuizQuestion], String?) {
        var picked: [QuizQuestion] = []
        var used = Set<ItemKey>()

        func take(_ qs: [QuizQuestion], limit: Int) -> Int {
            var taken = 0
            for q in qs where taken < limit && used.insert(q.id).inserted {
                picked.append(q)
                taken += 1
            }
            return taken
        }

        func pillarDrills(_ pillar: Pillar) -> [DrillKind] {
            let ordered = Self.allocation.map(\.drill) + DrillKind.allCases
            var seen = Set<DrillKind>()
            return ordered.filter { $0.pillar == pillar && factory($0) != nil && seen.insert($0).inserted }
        }

        /// Up to `need` unused questions from the pillar's drills, mixing drills round-robin.
        func fetch(_ pillar: Pillar, need: Int) -> Int {
            guard need > 0 else { return 0 }
            let pools: [[QuizQuestion]] = pillarDrills(pillar).compactMap { drill in
                factory(drill)?.makeQuestions(count: need + used.count + 5, scope: scope, seed: seed, rng: &rng)
            }
            var taken = 0
            var round = 0
            while taken < need, pools.contains(where: { round < $0.count }) {
                for pool in pools where round < pool.count && taken < need {
                    taken += take([pool[round]], limit: 1)
                }
                round += 1
            }
            return taken
        }

        // 1. The fixed per-drill allocation.
        var pillarTarget: [Pillar: Int] = [:]
        var pillarGot: [Pillar: Int] = [:]
        for (drill, count) in Self.allocation {
            pillarTarget[drill.pillar, default: 0] += count
            guard let f = factory(drill) else { continue }
            pillarGot[drill.pillar, default: 0] += take(f.makeQuestions(count: count, scope: scope, seed: seed, rng: &rng), limit: count)
        }
        // 2. A pillar's gap is filled from the pillar's other drills.
        for pillar in Pillar.allCases {
            let missing = (pillarTarget[pillar] ?? 0) - (pillarGot[pillar] ?? 0)
            pillarGot[pillar, default: 0] += fetch(pillar, need: missing)
        }
        // 3. A pillar that still cannot reach its allocation is made up proportionally by the other pillars.
        var shortfall = Self.questionCount - picked.count
        var note: String?
        if shortfall > 0 {
            let short = Pillar.allCases.filter { (pillarGot[$0] ?? 0) < (pillarTarget[$0] ?? 0) }
            let donors = Pillar.allCases.filter { (pillarTarget[$0] ?? 0) > 0 && !short.contains($0) }
            for _ in 0..<3 where shortfall > 0 && !donors.isEmpty {
                let weight = donors.reduce(0) { $0 + (pillarTarget[$1] ?? 0) }
                var remainingShortfall = shortfall
                for (i, pillar) in donors.enumerated() {
                    let share = i == donors.count - 1
                        ? remainingShortfall
                        : Int((Double(shortfall) * Double(pillarTarget[pillar] ?? 0) / Double(weight)).rounded())
                    let give = min(share, remainingShortfall)
                    let got = fetch(pillar, need: give)
                    remainingShortfall -= got
                }
                shortfall = Self.questionCount - picked.count
            }
            let names = short.map { $0.rawValue }.joined(separator: ", ")
            if !short.isEmpty {
                note = "Not enough \(names) items; the rest come from other pillars."
            }
        }
        // Keep pillar order, then allocation order.
        let order = Pillar.allCases
        let sorted = picked.enumerated().sorted {
            let a = order.firstIndex(of: $0.element.pillar) ?? 0, b = order.firstIndex(of: $1.element.pillar) ?? 0
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element)
        return (sorted, note)
    }

    // MARK: Answering

    public func setMode(_ newMode: InputMode) {
        guard let q = currentQuestion, q.supportedModes.contains(newMode) else { return }
        mode = newMode
    }

    /// Stores the choice for the current question (replacing an earlier one). No feedback is given.
    public func answerChoice(_ choice: String) {
        guard let q = currentQuestion, q.supportedModes.contains(.choice) else { return }
        answers[q.id] = (choice, .choice)
    }

    public func answerText(_ text: String) {
        guard let q = currentQuestion, q.supportedModes.contains(.typing) else { return }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            answers[q.id] = nil
        } else {
            answers[q.id] = (text, .typing)
        }
    }

    /// Moves forward (never back). On the last question this submits the exam.
    public func next() {
        guard phase == .running else { return }
        if isLastQuestion { submit() } else { index += 1 }
    }

    public func playPrompt(slow: Bool = false) {
        guard let text = currentQuestion?.speech else { return }
        speech?.speak(text, slow: slow)
    }

    /// Call about once a second while the exam screen is visible; submits when time is up.
    public func tick() {
        guard phase == .running, let startedAt else { return }
        remaining = max(0, Self.timeLimit - now().timeIntervalSince(startedAt))
        if remaining <= 0 { submit() }
    }

    /// Scores everything, records every answer once (unanswered = wrong) and shows the result.
    public func submit() {
        guard phase == .running, let startedAt else { return }
        let finishedAt = now()
        var correctCount = 0
        var unanswered = 0
        var scores: [Pillar: (correct: Int, total: Int)] = [:]
        var wrong: [QuizQuestion] = []
        for q in questions {
            let given = answers[q.id]
            let isCorrect: Bool
            switch given?.mode {
            case .choice?: isCorrect = given?.value == q.correctChoice
            case .typing?: isCorrect = TypingValidator.isCorrect(given?.value ?? "", accepted: q.acceptedAnswers)
            case nil: isCorrect = false
            }
            if given == nil { unanswered += 1 }
            if isCorrect { correctCount += 1 } else { wrong.append(q) }
            var s = scores[q.pillar] ?? (0, 0)
            s.total += 1
            if isCorrect { s.correct += 1 }
            scores[q.pillar] = s
            repository.record(q.id, pillar: q.pillar, correct: isCorrect, mode: given?.mode ?? .choice, at: finishedAt)
        }
        result = Result(
            total: questions.count, correct: correctCount, unanswered: unanswered,
            duration: min(max(0, finishedAt.timeIntervalSince(startedAt)), Self.timeLimit),
            byPillar: Pillar.allCases.compactMap { p in scores[p].map { PillarScore(pillar: p, correct: $0.correct, total: $0.total) } },
            wrongQuestions: wrong
        )
        remaining = max(0, Self.timeLimit - finishedAt.timeIntervalSince(startedAt))
        phase = .finished
    }

    /// A normal quiz over the wrongly answered (or unanswered) questions.
    public func makeRetrySession() -> QuizSessionViewModel? {
        guard let wrong = result?.wrongQuestions, !wrong.isEmpty else { return nil }
        return QuizSessionViewModel(questions: wrong, initialMode: mode, repository: repository, speech: speech, now: now)
    }

    public func reset() {
        phase = .notStarted
        questions = []
        result = nil
        note = nil
        answers = [:]
        remaining = Self.timeLimit
    }
}

/// Type-erased RNG so the exam can use either a seeded or the system generator.
struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var generator: any RandomNumberGenerator

    init(_ generator: some RandomNumberGenerator) { self.generator = generator }

    mutating func next() -> UInt64 { generator.next() }
}
