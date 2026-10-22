import Testing
@testable import KachiiroCore

enum FactoryTestSupport {
    /// Invariants every drill must satisfy.
    static func expectWellFormed(_ questions: [QuizQuestion], _ factory: some QuestionFactory, sourceLocation: SourceLocation = #_sourceLocation) {
        for q in questions {
            #expect(q.drill == factory.drill, sourceLocation: sourceLocation)
            #expect(q.pillar == factory.drill.pillar, sourceLocation: sourceLocation)
            #expect(q.acceptedAnswers.contains(q.correctChoice), "\(q.id.raw)", sourceLocation: sourceLocation)
            if q.supportedModes.contains(.choice) {
                #expect(q.choices.count == 4, "\(q.id.raw)", sourceLocation: sourceLocation)
                #expect(Set(q.choices).count == 4, "\(q.id.raw) \(q.choices)", sourceLocation: sourceLocation)
                #expect(q.choices.contains(q.correctChoice), "\(q.id.raw)", sourceLocation: sourceLocation)
                #expect(q.choices.filter { q.acceptedAnswers.contains($0) }.count == 1, "\(q.id.raw) \(q.choices)", sourceLocation: sourceLocation)
            } else {
                #expect(q.choices.isEmpty, sourceLocation: sourceLocation)
            }
        }
        #expect(Set(questions.map(\.id)).count == questions.count, sourceLocation: sourceLocation)
    }

    static func expectRoundTrip(_ questions: [QuizQuestion], _ factory: some QuestionFactory, seed: SeedData, sourceLocation: SourceLocation = #_sourceLocation) {
        for q in questions {
            let again = factory.question(for: q.id, seed: seed)
            #expect(again?.id == q.id, "\(q.id.raw)", sourceLocation: sourceLocation)
            #expect(again?.correctChoice == q.correctChoice, "\(q.id.raw)", sourceLocation: sourceLocation)
            #expect(again?.promptBody == q.promptBody, sourceLocation: sourceLocation)
            #expect(again?.acceptedAnswers == q.acceptedAnswers, sourceLocation: sourceLocation)
            if let again { expectWellFormed([again], factory, sourceLocation: sourceLocation) }
            // Registry dispatches on the key prefix to the same factory.
            #expect(QuestionFactoryRegistry.question(for: q.id, seed: seed)?.correctChoice == q.correctChoice, sourceLocation: sourceLocation)
        }
    }
}
