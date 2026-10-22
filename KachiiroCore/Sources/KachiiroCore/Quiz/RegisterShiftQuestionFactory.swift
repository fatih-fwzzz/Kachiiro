/// Plain ↔ polite register shift: given one form, produce the other for the same tense and polarity.
public struct RegisterShiftQuestionFactory: QuestionFactory {
    public init() {}
    public var drill: DrillKind { .registerShift }

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
            guard let tense = Tense.allCases.randomElement(using: &rng),
                  let polarity = Polarity.allCases.randomElement(using: &rng) else { break }
            let toPlain = Bool.random(using: &rng)
            guard used.insert(.register(word.id, tense: tense, polarity: polarity, toPlain: toPlain)).inserted else { continue }
            if let q = build(word, tense, polarity, toPlain: toPlain, pool: pool, rng: &rng) { out.append(q) }
        }
        return out
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        guard key.prefix == "register", key.parts.count == 3, let id = key.id,
              let word = seed.word(id: id), FactorySupport.inflectable(word) else { return nil }
        let tp = key.parts[1].split(separator: "-").map(String.init)
        guard tp.count == 2, let tense = Tense(rawValue: tp[0]), let polarity = Polarity(rawValue: tp[1]),
              ["p2n", "n2p"].contains(key.parts[2]) else { return nil }
        var rng = FactorySupport.stableRNG(key)
        return build(word, tense, polarity, toPlain: key.parts[2] == "p2n",
                     pool: seed.words.filter(FactorySupport.inflectable), rng: &rng)
    }

    private func build(
        _ word: Word, _ tense: Tense, _ polarity: Polarity, toPlain: Bool, pool: [Word], rng: inout some RandomNumberGenerator
    ) -> QuizQuestion? {
        guard let lexeme = Lexeme(word: word) else { return nil }
        let from = InflectionCell(politeness: toPlain ? .polite : .plain, tense: tense, polarity: polarity)
        let to = from.registerSwapped
        let shown = InflectionEngine.inflect(lexeme, cell: from)
        let answer = InflectionEngine.inflect(lexeme, cell: to)
        let kana = Lexeme(headword: word.reading, reading: word.reading, kind: lexeme.kind)

        let sameLexeme = InflectionCell.all.filter { $0 != to }.map { InflectionEngine.inflect(lexeme, cell: $0).display }
        let sameKind: [Lexeme] = Array(
            pool.shuffled(using: &rng).lazy
                .filter { $0.id != word.id }
                .compactMap { w in Lexeme(word: w).flatMap { $0.kind == lexeme.kind ? $0 : nil } }
                .prefix(10)
        )
        let sameCell: [String] = sameKind.map { InflectionEngine.inflect($0, cell: to).display }
        guard let d = DistractorPicker.pick(
            correct: answer.display, accepted: answer.accepted, tiers: [sameLexeme, sameCell], rng: &rng
        ) else { return nil }

        let direction = toPlain ? "Polite → Plain" : "Plain → Polite"
        return QuizQuestion(
            id: .register(word.id, tense: tense, polarity: polarity, toPlain: toPlain), drill: .registerShift,
            promptTitle: "\(direction) · \(tense == .nonPast ? "Non-past" : "Past") · \(polarity == .affirmative ? "Affirmative" : "Negative")",
            promptBody: shown.display, promptReading: InflectionEngine.inflect(kana, cell: from).display,
            choices: FactorySupport.shuffledChoices(correct: answer.display, distractors: d, rng: &rng),
            correctChoice: answer.display, acceptedAnswers: answer.accepted,
            explanation: "\(from.label) → \(to.label) (\(ConjugationRule.groupName(lexeme.kind)))",
            supportedModes: [.choice, .typing]
        )
    }
}
