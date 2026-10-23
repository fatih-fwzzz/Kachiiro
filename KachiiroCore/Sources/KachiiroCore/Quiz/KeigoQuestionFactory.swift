/// Keigo transformer: turn a verb or a whole sentence into 尊敬語, 謙譲語 or 丁寧語.
/// Keigo content is authored, so scope and seed are ignored.
public struct KeigoQuestionFactory: QuestionFactory {
    private let content: KeigoContent

    public init(content: KeigoContent = .bundled) { self.content = content }
    public var drill: DrillKind { .keigo }

    public func makeQuestions(count: Int, scope: StudyScope, seed: SeedData, rng: inout some RandomNumberGenerator) -> [QuizQuestion] {
        guard count > 0 else { return [] }
        var sentenceKeys = content.sentences.map { ItemKey.keigoSentence($0.id) }.shuffled(using: &rng)
        var verbKeys = content.verbs.flatMap { v in
            KeigoLevel.allCases.filter { !KeigoEngine.forms(v, $0).isEmpty }.map { ItemKey.keigoVerb(v.id, $0) }
        }.shuffled(using: &rng)

        var sentenceCount = min((count + 1) / 2, sentenceKeys.count)
        var verbCount = min(count - sentenceCount, verbKeys.count)
        sentenceCount = min(count - verbCount, sentenceKeys.count)
        verbCount = min(count - sentenceCount, verbKeys.count)
        sentenceKeys = Array(sentenceKeys.prefix(sentenceCount))
        verbKeys = Array(verbKeys.prefix(verbCount))

        return (sentenceKeys + verbKeys).shuffled(using: &rng).compactMap { question(for: $0, seed: seed) }
    }

    public func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? {
        var rng = FactorySupport.stableRNG(key)
        let p = key.parts
        if key.prefix == "keigo", p.count == 2, p[0] == "s", let id = Int(p[1]),
           let s = content.sentences.first(where: { $0.id == id }) {
            return sentenceQuestion(s, rng: &rng)
        }
        if key.prefix == "keigo", p.count == 3, p[0] == "v", let id = Int(p[1]),
           let level = KeigoLevel.allCases.first(where: { $0.short == p[2] }),
           let v = content.verbs.first(where: { $0.id == id }), !KeigoEngine.forms(v, level).isEmpty {
            return verbQuestion(v, level, rng: &rng)
        }
        return nil
    }

    private func verbQuestion(_ v: KeigoVerb, _ level: KeigoLevel, rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        let forms = KeigoEngine.forms(v, level)
        guard let correct = forms.first else { return nil }
        let accepted = KeigoEngine.accepted(v, level)
        let otherLevels = KeigoLevel.allCases.filter { $0 != level }.flatMap { KeigoEngine.forms(v, $0) } + [v.polite]
        let otherVerbs = content.verbs.filter { $0.id != v.id }.compactMap { KeigoEngine.forms($0, level).first }
        let distractors = DistractorPicker.pick(correct: correct, accepted: accepted, tiers: [otherLevels, otherVerbs], rng: &rng)

        var explanation = "\(level.rule) \(v.plain) → \(forms.joined(separator: "・"))"
        if level == .sonkeigo, let r = v.rareru { explanation += " (\(r) is also accepted but less formal.)" }
        return QuizQuestion(
            id: .keigoVerb(v.id, level), drill: .keigo,
            promptTitle: level.label, promptBody: "\(v.plain)（\(v.meaning)）", promptReading: v.reading,
            choices: distractors.map { FactorySupport.shuffledChoices(correct: correct, distractors: $0, rng: &rng) } ?? [],
            correctChoice: correct, acceptedAnswers: accepted, explanation: explanation,
            supportedModes: distractors == nil ? [.typing] : [.choice, .typing],
            isSpeakable: true,
            judgingContext: "Convert the verb \(v.plain) (\(v.meaning)) to \(level.rawValue) in polite ます form."
        )
    }

    private func sentenceQuestion(_ s: KeigoSentence, rng: inout some RandomNumberGenerator) -> QuizQuestion? {
        guard let correct = s.answers.first else { return nil }
        return QuizQuestion(
            id: .keigoSentence(s.id), drill: .keigo,
            promptTitle: "To \(s.listener.label) · \(s.target.label)", promptBody: s.plain,
            choices: FactorySupport.shuffledChoices(correct: correct, distractors: s.wrong, rng: &rng),
            correctChoice: correct, acceptedAnswers: s.answers, explanation: s.explanation,
            keyPhrases: s.keyPhrases, isSpeakable: true,
            judgingContext: "Situation: \(s.situation). Listener: \(s.listener.label). Say this in \(s.target.rawValue): \(s.plain)"
        )
    }
}
