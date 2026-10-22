public struct PitchQuestionFactory: QuestionFactory {
    public init() {}
    public var drill: DrillKind { .pitch }

    /// The four options, always in this order.
    public static let options: [(type: PitchPattern.AccentType, label: String)] = [
        (.heiban, "平板 (heiban)"), (.atamadaka, "頭高 (atamadaka)"), (.nakadaka, "中高 (nakadaka)"), (.odaka, "尾高 (odaka)"),
    ]

    private static func pattern(_ word: Word) -> PitchPattern? {
        guard let p = PitchPattern.parse(pitch: word.pitch, reading: word.reading), p.moraCount >= 2 else { return nil }
        return p
    }

    public func makeQuestions(count: Int, scope: StudyScope, seed: SeedData, rng: inout some RandomNumberGenerator) -> [QuizQuestion] {
        let pool = FactorySupport.words(seed, scope) { Self.pattern($0) != nil }
        guard !pool.isEmpty, count > 0 else { return [] }
        return pool.shuffled(using: &rng).prefix(count).compactMap { build($0) }
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        guard key.prefix == "pitch", let id = key.id, let word = seed.word(id: id) else { return nil }
        return build(word)
    }

    private func build(_ word: Word) -> QuizQuestion? {
        guard let p = Self.pattern(word), let correct = Self.options.first(where: { $0.type == p.accentType })?.label else { return nil }
        let drop = p.dropAfter.map { "drops after mora \($0)" } ?? "flat (no drop)"
        return QuizQuestion(
            id: .pitch(word.id), drill: .pitch,
            promptTitle: "Accent type · typing: mora before the drop (0 = flat)",
            promptBody: word.headword, promptReading: word.reading, pitch: p,
            choices: Self.options.map(\.label), correctChoice: correct,
            acceptedAnswers: [correct, String(p.dropAfter ?? 0)],
            explanation: "\(correct): \(drop)", supportedModes: [.choice, .typing]
        )
    }
}
