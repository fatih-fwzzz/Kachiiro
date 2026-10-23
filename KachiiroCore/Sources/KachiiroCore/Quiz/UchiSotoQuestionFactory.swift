/// Register choices that depend on in-group (uchi) versus out-group (soto).
public struct UchiSotoQuestionFactory: QuestionFactory {
    private let content: KeigoContent

    public init(content: KeigoContent = .bundled) { self.content = content }
    public var drill: DrillKind { .uchiSoto }

    public func makeQuestions(count: Int, scope: StudyScope, seed: SeedData, rng: inout some RandomNumberGenerator) -> [QuizQuestion] {
        guard count > 0 else { return [] }
        return content.uchiSoto.shuffled(using: &rng).prefix(count).compactMap { build($0, rng: &rng) }
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        guard key.prefix == "uchi", let id = key.id, let item = content.uchiSoto.first(where: { $0.id == id }) else { return nil }
        var rng = FactorySupport.stableRNG(key)
        return build(item, rng: &rng)
    }

    private func build(_ item: UchiSotoItem, rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        guard Set(item.choices).count == 4, item.choices.contains(item.answer) else { return nil }
        return QuizQuestion(
            id: .uchiSoto(item.id), drill: .uchiSoto,
            promptTitle: item.situation, promptBody: item.question,
            choices: item.choices.shuffled(using: &rng), correctChoice: item.answer,
            explanation: item.explanation, supportedModes: [.choice]
        )
    }
}
