public struct PatternQuestionFactory: QuestionFactory {
    public init() {}
    public var drill: DrillKind { .patternRecognition }

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
        guard key.prefix == "pattern", let id = key.id, let pattern = seed.pattern(id: id) else { return nil }
        var rng = FactorySupport.stableRNG(key)
        return build(pattern, all: seed.patterns, rng: &rng)
    }

    private func build(_ p: GrammarPattern, all: [GrammarPattern], rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        let others = all.filter { $0.id != p.id && $0.pattern != p.pattern }
        let tiers = [others.filter { $0.level == p.level }, others].map { $0.map(\.pattern) }
        guard let d = DistractorPicker.pick(correct: p.pattern, accepted: [p.pattern], tiers: tiers, rng: &rng) else { return nil }
        return QuizQuestion(
            id: .pattern(p.id), drill: .patternRecognition, promptTitle: "Which pattern is used?",
            promptBody: p.example, choices: FactorySupport.shuffledChoices(correct: p.pattern, distractors: d, rng: &rng),
            correctChoice: p.pattern, explanation: "第\(p.lesson)課 \(p.lessonTitle) · \(p.topic)", supportedModes: [.choice]
        )
    }
}
