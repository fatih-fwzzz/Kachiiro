public struct VocabQuestionFactory: QuestionFactory {
    public init() {}
    public var drill: DrillKind { .vocab }

    private static func pool(_ seed: SeedData, _ scope: StudyScope) -> [Word] {
        FactorySupport.words(seed, scope) { !$0.meaning.isEmpty && !$0.headword.isEmpty }
    }

    public func makeQuestions(count: Int, scope: StudyScope, seed: SeedData, rng: inout some RandomNumberGenerator) -> [QuizQuestion] {
        let pool = Self.pool(seed, scope)
        guard !pool.isEmpty, count > 0 else { return [] }
        let order = pool.shuffled(using: &rng)
        var out: [QuizQuestion] = []
        var used = Set<ItemKey>()
        var attempts = 0
        while out.count < count, attempts < count * 20 {
            let word = order[attempts % order.count]
            attempts += 1
            let reverse = Bool.random(using: &rng)
            guard used.insert(.vocab(word.id, reverse: reverse)).inserted else { continue }
            if let q = build(word, reverse: reverse, pool: pool, rng: &rng) { out.append(q) }
        }
        return out
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        guard key.prefix == "vocab", key.parts.count == 2, let id = key.id, let word = seed.word(id: id),
              ["m2w", "w2m"].contains(key.parts[1]) else { return nil }
        var rng = FactorySupport.stableRNG(key)
        return build(word, reverse: key.parts[1] == "w2m", pool: seed.words.filter { !$0.meaning.isEmpty }, rng: &rng)
    }

    private func build(_ word: Word, reverse: Bool, pool: [Word], rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        // Same headword or same meaning would make a distractor arguably correct.
        let others = pool.filter { $0.headword != word.headword && $0.meaning != word.meaning }
        let samePosLevel = others.filter { $0.pos == word.pos && $0.level == word.level }
        let samePos = others.filter { $0.pos == word.pos }
        let note = word.contextNote.isEmpty ? "" : " (\(word.contextNote))"
        let explanation = "\(word.headword)\(note) · \(word.reading) · \(word.meaning)"

        if reverse {
            let tiers = [samePosLevel, samePos, others].map { $0.map(\.meaning) }
            guard let d = DistractorPicker.pick(correct: word.meaning, accepted: [word.meaning], tiers: tiers, rng: &rng) else { return nil }
            return QuizQuestion(
                id: .vocab(word.id, reverse: true), drill: .vocab, promptTitle: "Japanese → English",
                promptBody: word.headword, promptReading: word.reading,
                pitch: PitchPattern.parse(pitch: word.pitch, reading: word.reading),
                choices: FactorySupport.shuffledChoices(correct: word.meaning, distractors: d, rng: &rng),
                correctChoice: word.meaning, explanation: explanation, supportedModes: [.choice]
            )
        }
        let accepted = [word.headword, word.reading] + word.alternates
        let tiers = [samePosLevel, samePos, others].map { $0.map(\.headword) }
        guard let d = DistractorPicker.pick(correct: word.headword, accepted: accepted, tiers: tiers, rng: &rng) else { return nil }
        return QuizQuestion(
            id: .vocab(word.id, reverse: false), drill: .vocab, promptTitle: "English → Japanese · \(word.pos.label)",
            promptBody: word.meaning, choices: FactorySupport.shuffledChoices(correct: word.headword, distractors: d, rng: &rng),
            correctChoice: word.headword, acceptedAnswers: accepted, explanation: explanation, supportedModes: [.choice, .typing]
        )
    }
}
