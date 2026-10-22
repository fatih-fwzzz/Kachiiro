/// Listen to an example sentence and choose the written sentence.
public struct SentenceListeningFactory: QuestionFactory {
    public init() {}
    public var drill: DrillKind { .sentenceListening }

    public func makeQuestions(count: Int, scope: StudyScope, seed: SeedData, rng: inout some RandomNumberGenerator) -> [QuizQuestion] {
        let pool = seed.patterns.filter { scope.contains(level: $0.level, lesson: $0.lesson) }
        guard count > 0 else { return [] }
        var out: [QuizQuestion] = []
        for p in pool.shuffled(using: &rng) {
            if let q = build(p, all: seed.patterns, rng: &rng) { out.append(q) }
            if out.count == count { break }
        }
        return out
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        guard key.prefix == "sent", let id = key.id, let p = seed.pattern(id: id) else { return nil }
        var rng = FactorySupport.stableRNG(key)
        return build(p, all: seed.patterns, rng: &rng)
    }

    private func build(_ p: GrammarPattern, all: [GrammarPattern], rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        let others = all.filter { $0.id != p.id && $0.example != p.example }
        let tiers = [others.filter { $0.level == p.level }, others].map { $0.map(\.example) }
        guard let d = DistractorPicker.pick(correct: p.example, accepted: [p.example], tiers: tiers, rng: &rng) else { return nil }
        return QuizQuestion(
            id: .sent(p.id), drill: .sentenceListening, promptTitle: "Sentence listening", promptBody: "Listen and choose",
            speech: p.example, choices: FactorySupport.shuffledChoices(correct: p.example, distractors: d, rng: &rng),
            correctChoice: p.example, explanation: "\(p.pattern) · 第\(p.lesson)課 \(p.lessonTitle)", supportedModes: [.choice]
        )
    }
}
