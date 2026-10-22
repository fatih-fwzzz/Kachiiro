public struct InflectionQuestionFactory: QuestionFactory {
    public init() {}
    public var drill: DrillKind { .inflectionMatrix }

    private static func pool(_ seed: SeedData, _ scope: StudyScope) -> [Word] {
        FactorySupport.words(seed, scope, where: FactorySupport.inflectable)
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
            guard let cell = InflectionCell.all.randomElement(using: &rng),
                  used.insert(.infl(word.id, cell)).inserted else { continue }
            if let q = build(word, cell, pool: pool, rng: &rng) { out.append(q) }
        }
        return out
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        guard key.prefix == "infl", key.parts.count == 2, let id = key.id,
              let cell = InflectionCell(raw: key.parts[1]), let word = seed.word(id: id),
              FactorySupport.inflectable(word) else { return nil }
        var rng = FactorySupport.stableRNG(key)
        return build(word, cell, pool: seed.words.filter(FactorySupport.inflectable), rng: &rng)
    }

    private func build(_ word: Word, _ cell: InflectionCell, pool: [Word], rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        guard let lexeme = Lexeme(word: word) else { return nil }
        let answer = InflectionEngine.inflect(lexeme, cell: cell)

        let sameLexeme = InflectionCell.all.filter { $0 != cell }.map { InflectionEngine.inflect(lexeme, cell: $0).display }
        let sameKind: [Lexeme] = Array(
            pool.shuffled(using: &rng).lazy
                .filter { $0.id != word.id }
                .compactMap { w in Lexeme(word: w).flatMap { $0.kind == lexeme.kind ? $0 : nil } }
                .prefix(10)
        )
        let swapped: [String] = sameKind.map { InflectionEngine.inflect($0, cell: cell.registerSwapped).display }
        let sameCell: [String] = sameKind.map { InflectionEngine.inflect($0, cell: cell).display }
        guard let distractors = DistractorPicker.pick(
            correct: answer.display, accepted: answer.accepted, tiers: [sameLexeme, swapped, sameCell], rng: &rng
        ) else { return nil }

        return QuizQuestion(
            id: .infl(word.id, cell), drill: .inflectionMatrix, promptTitle: cell.label, promptBody: word.headword,
            promptReading: word.reading,
            choices: FactorySupport.shuffledChoices(correct: answer.display, distractors: distractors, rng: &rng),
            correctChoice: answer.display, acceptedAnswers: answer.accepted,
            explanation: "\(ConjugationRule.groupName(lexeme.kind)) · \(cell.label)", supportedModes: [.choice, .typing]
        )
    }
}
