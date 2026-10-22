public struct VerbFormQuestionFactory: QuestionFactory {
    public init() {}
    public var drill: DrillKind { .verbForms }

    private static func pool(_ seed: SeedData, _ scope: StudyScope) -> [Word] {
        FactorySupport.words(seed, scope) { $0.pos.isVerb }
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
            guard let form = VerbForm.allCases.randomElement(using: &rng) else { break }
            guard used.insert(.verb(word.id, form)).inserted else { continue }
            if let q = build(word, form, pool: pool, rng: &rng) { out.append(q) }
        }
        return out
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        guard key.prefix == "verb", key.parts.count == 2, let id = key.id,
              let form = VerbForm(rawValue: key.parts[1]), let word = seed.word(id: id), word.pos.isVerb else { return nil }
        var rng = FactorySupport.stableRNG(key)
        return build(word, form, pool: seed.words.filter { $0.pos.isVerb }, rng: &rng)
    }

    private func build(_ word: Word, _ form: VerbForm, pool: [Word], rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        guard let lexeme = Lexeme(word: word), let answer = KatsuyouEngine.conjugate(lexeme, form: form) else { return nil }
        let reverse = form == .dictionary
        var body = word.headword
        var reading = word.reading
        var title = form.label
        if reverse {
            guard let masu = KatsuyouEngine.conjugate(lexeme, form: .masu) else { return nil }
            let kana = Lexeme(headword: word.reading, reading: word.reading, kind: lexeme.kind)
            body = masu.display
            reading = KatsuyouEngine.conjugate(kana, form: .masu)?.display ?? word.reading
            title = "辞書形 / dictionary form"
        }

        var sameLexeme: [String] = []
        for other in VerbForm.allCases where other != form && !(reverse && other == .masu) {
            if let c = KatsuyouEngine.conjugate(lexeme, form: other) { sameLexeme.append(c.display) }
        }
        let wrongGroups: [String] = reverse ? [] : [LexemeKind.godan, .ichidan, .suruKuru]
            .filter { $0 != lexeme.kind }
            .compactMap { KatsuyouEngine.conjugate(lexeme, form: form, as: $0)?.display }
        let others = pool.shuffled(using: &rng).prefix(16).filter { $0.id != word.id }
        let sameForm: [String] = others.compactMap { w in
            Lexeme(word: w).flatMap { KatsuyouEngine.conjugate($0, form: form)?.display }
        }
        let sameGroup: [String] = others.filter { $0.pos == word.pos }.compactMap { w in
            Lexeme(word: w).flatMap { KatsuyouEngine.conjugate($0, form: form)?.display }
        }

        let tiers = reverse ? [sameLexeme.filter { $0 != answer.display }, sameGroup, sameForm]
            : [sameLexeme, wrongGroups, sameGroup, sameForm]
        guard let distractors = DistractorPicker.pick(
            correct: answer.display, accepted: answer.accepted, tiers: tiers, rng: &rng
        ) else { return nil }

        return QuizQuestion(
            id: .verb(word.id, form), drill: .verbForms, promptTitle: title, promptBody: body,
            promptReading: reading, choices: FactorySupport.shuffledChoices(correct: answer.display, distractors: distractors, rng: &rng),
            correctChoice: answer.display, acceptedAnswers: answer.accepted,
            explanation: ConjugationRule.hint(lexeme, form: form), supportedModes: [.choice, .typing]
        )
    }
}
