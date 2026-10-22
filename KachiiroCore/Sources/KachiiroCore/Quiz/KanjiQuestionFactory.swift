public struct KanjiQuestionFactory: QuestionFactory {
    public init() {}
    public var drill: DrillKind { .kanji }

    private static func pool(_ seed: SeedData, _ scope: StudyScope) -> [KanjiEntry] {
        seed.kanji.filter { scope.contains(level: $0.level, lesson: $0.lesson) }
    }

    public func makeQuestions(count: Int, scope: StudyScope, seed: SeedData, rng: inout some RandomNumberGenerator) -> [QuizQuestion] {
        let pool = Self.pool(seed, scope)
        guard !pool.isEmpty, count > 0 else { return [] }
        let order = pool.shuffled(using: &rng)
        var out: [QuizQuestion] = []
        var used = Set<ItemKey>()
        var attempts = 0
        while out.count < count, attempts < count * 20 {
            let row = order[attempts % order.count]
            attempts += 1
            let writing = Bool.random(using: &rng)
            guard used.insert(.kanji(row.id, writing: writing)).inserted else { continue }
            if let q = build(row, writing: writing, pool: pool, rng: &rng) { out.append(q) }
        }
        return out
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        guard key.prefix == "kanji", key.parts.count == 2, let id = key.id, let row = seed.kanjiEntry(id: id),
              ["r", "w"].contains(key.parts[1]) else { return nil }
        var rng = FactorySupport.stableRNG(key)
        return build(row, writing: key.parts[1] == "w", pool: seed.kanji, rng: &rng)
    }

    /// Affix markers (`～以上`) are dropped so every answer can be typed.
    private static func plain(_ s: String) -> String {
        s.replacingOccurrences(of: "～", with: "").replacingOccurrences(of: "〜", with: "")
    }

    private func build(_ row: KanjiEntry, writing: Bool, pool: [KanjiEntry], rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        let word = Self.plain(row.word)
        let wordReading = Self.plain(row.wordReading)
        guard !word.isEmpty, !wordReading.isEmpty else { return nil }
        let explanation = "\(row.kanji) (\(row.reading)) in \(word) · \(wordReading)"
        if writing {
            // Rows that read the same are homophones and could also be right.
            let others = pool.filter { Self.plain($0.wordReading) != wordReading && !$0.word.contains(row.kanji) }
            let tiers = [others.filter { $0.level == row.level }, others].map { $0.map { Self.plain($0.word) } }
            guard let d = DistractorPicker.pick(correct: word, accepted: [word], tiers: tiers, rng: &rng) else { return nil }
            return QuizQuestion(
                id: .kanji(row.id, writing: true), drill: .kanji, promptTitle: "Write with kanji · \(row.kanji)",
                promptBody: wordReading, choices: FactorySupport.shuffledChoices(correct: word, distractors: d, rng: &rng),
                correctChoice: word, explanation: explanation, supportedModes: [.choice, .typing]
            )
        }
        let others = pool.filter { Self.plain($0.word) != word }
        let tiers = [others.filter { $0.level == row.level }, others].map { $0.map { Self.plain($0.wordReading) } }
        guard let d = DistractorPicker.pick(correct: wordReading, accepted: [wordReading], tiers: tiers, rng: &rng) else { return nil }
        return QuizQuestion(
            id: .kanji(row.id, writing: false), drill: .kanji, promptTitle: "Reading · \(row.kanji)",
            promptBody: word, choices: FactorySupport.shuffledChoices(correct: wordReading, distractors: d, rng: &rng),
            correctChoice: wordReading, explanation: explanation, supportedModes: [.choice, .typing]
        )
    }
}
