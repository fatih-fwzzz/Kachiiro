public protocol QuestionFactory: Sendable {
    var drill: DrillKind { get }
    func makeQuestions(count: Int, scope: StudyScope, seed: SeedData, rng: inout some RandomNumberGenerator) -> [QuizQuestion]
    func question(for key: ItemKey, seed: SeedData) -> QuizQuestion?
}

public extension QuestionFactory {
    func makeQuestions(count: Int, scope: StudyScope, seed: SeedData) -> [QuizQuestion] {
        var rng = SystemRandomNumberGenerator()
        return makeQuestions(count: count, scope: scope, seed: seed, rng: &rng)
    }
}

public enum QuestionFactoryRegistry {
    public static let all: [any QuestionFactory] = [
        VerbFormQuestionFactory(),
        InflectionQuestionFactory(),
        VocabQuestionFactory(),
        KanjiQuestionFactory(),
        PitchQuestionFactory(),
    ]

    public static func factory(for drill: DrillKind) -> (any QuestionFactory)? {
        all.first { $0.drill == drill }
    }

    /// Dispatches on the key prefix; `nil` when the item no longer exists.
    public static func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        key.drill.flatMap(factory(for:))?.question(for: key, seed: seed)
    }
}
