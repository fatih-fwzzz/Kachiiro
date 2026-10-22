/// Listen to the reading (spoken by TTS) and pick or type the word.
public struct DictationQuestionFactory: QuestionFactory {
    public init() {}
    public var drill: DrillKind { .dictation }

    private static func eligible(_ w: Word) -> Bool {
        (2...12).contains(w.reading.count) && !w.reading.contains("～") && FactorySupport.isPlainJapanese(w.reading)
            && !w.headword.isEmpty
    }

    public func makeQuestions(count: Int, scope: StudyScope, seed: SeedData, rng: inout some RandomNumberGenerator) -> [QuizQuestion] {
        let pool = FactorySupport.words(seed, scope, where: Self.eligible)
        guard count > 0 else { return [] }
        var out: [QuizQuestion] = []
        for word in pool.shuffled(using: &rng) {
            if let q = build(word, pool: pool, rng: &rng) { out.append(q) }
            if out.count == count { break }
        }
        return out
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        guard key.prefix == "dict", let id = key.id, let word = seed.word(id: id), Self.eligible(word) else { return nil }
        var rng = FactorySupport.stableRNG(key)
        return build(word, pool: seed.words.filter(Self.eligible), rng: &rng)
    }

    private func build(_ word: Word, pool: [Word], rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        // Homophones would sound identical, so they cannot be distractors.
        let others = pool.filter { $0.reading != word.reading && $0.headword != word.headword }
        let tiers = [others.filter { $0.pos == word.pos }, others].map { $0.map(\.headword) }
        let accepted = [word.headword, word.reading] + word.alternates
        guard let d = DistractorPicker.pick(correct: word.headword, accepted: accepted, tiers: tiers, rng: &rng) else { return nil }
        return QuizQuestion(
            id: .dict(word.id), drill: .dictation, promptTitle: "Dictation", promptBody: "Listen and answer",
            speech: word.reading, choices: FactorySupport.shuffledChoices(correct: word.headword, distractors: d, rng: &rng),
            correctChoice: word.headword, acceptedAnswers: accepted,
            explanation: "\(word.headword) · \(word.reading) · \(word.meaning)", supportedModes: [.choice, .typing]
        )
    }
}
