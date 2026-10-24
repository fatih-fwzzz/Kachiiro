import Foundation

public struct KeigoJudgement: Codable, Equatable, Sendable {
    public let acceptable: Bool
    public let corrected: String
    public let explanation: String

    public init(acceptable: Bool, corrected: String, explanation: String) {
        self.acceptable = acceptable
        self.corrected = corrected
        self.explanation = explanation
    }
}

public struct PartnerTurn: Codable, Equatable, Sendable {
    public let partnerLine: String
    public let feedback: KeigoJudgement
    public let finished: Bool
}

public protocol AnswerJudging: Sendable {
    func judge(answer: String, question: QuizQuestion) async throws -> KeigoJudgement
}

enum KaiwaPrompts {
    static let system = "You are a Japanese keigo coach for a learner at JLPT N4–N3 level preparing to work in Japan. Write Japanese in natural kanji with standard okurigana. Every Japanese field is a complete, natural Japanese sentence, never a label, description or English. Write explanations in English, at most two sentences. Respond only with JSON that matches the schema."

    static func judge(context: String, accepted: [String], answer: String) -> String {
        """
        Situation: \(context)
        Model answers: \(accepted.joined(separator: " / "))
        Learner said: \(answer)
        Is the learner's sentence natural Japanese with the correct keigo for this situation? Small wording or particle differences are fine if the keigo is correct. `corrected` is the best version of the learner's sentence.
        """
    }

    static func keigoItems(count: Int) -> String {
        """
        Create \(count) varied workplace and service keigo exercises. Mix the three targets.
        - sonkeigo raises the action of the listener or a superior (いらっしゃる, おっしゃる, ご覧になる).
        - kenjougo lowers the speaker's own action (参る, 申す, 拝見する, いたす).
        - teineigo is polite です/ます speech, including ございます.
        `plain` is the casual sentence. `answer` is the same meaning in the target keigo. `wrong` is exactly three complete Japanese sentences with typical mistakes: keigo in the wrong direction, plain ます form, and double keigo.
        Example item: {"situation": "Asking your manager when they will arrive tomorrow", "listener": "boss", "target": "sonkeigo", "plain": "部長は明日何時に来る？", "answer": "部長は明日何時にいらっしゃいますか。", "wrong": ["部長は明日何時に参りますか。", "部長は明日何時に来ますか。", "部長は明日何時にいらっしゃられますか。"], "explanation": "Your manager is the one coming, so raise their action with いらっしゃる."}
        """
    }

    static func uchiSotoItems(count: Int) -> String {
        """
        Create \(count) uchi/soto register-choice questions: talking about your own company's people to outsiders, phone calls, reception, or about family to a teacher.
        `choices` are four complete Japanese sentences the speaker could say; exactly one is right.
        Example item: {"situation": "A client calls and asks for your manager, 田中部長, who is out.", "question": "What do you say to the client?", "choices": ["田中は今席を外しております。", "田中部長は席を外されました。", "田中部長は今席を外していらっしゃいます。", "田中さんは今席にいらっしゃいません。"], "answerIndex": 0, "explanation": "To an outsider your own manager is inside: drop the title and use humble ております."}
        """
    }

    static func shadowingLines(count: Int) -> String {
        """
        Create \(count) different short business keigo phrases for shadowing practice, each under 25 characters.
        Example item: {"text": "少々お待ちください。", "reading": "しょうしょうおまちください。", "meaning": "Please wait a moment."}
        """
    }

    static func partnerTurn(scenario: RoleplayScenario, history: String) -> String {
        "Scenario: \(scenario.setting) You play: \(scenario.partnerRole). The learner plays: \(scenario.userRole), named リン. You are never リン: never say リン's lines or introduce yourself as リン. Goal: \(scenario.goal). Reply only as \(scenario.partnerRole), in one or two short sentences, in the register this scenario requires. If the conversation is empty, open it as \(scenario.partnerRole) would, for example a receptionist answers the phone with the company name. In `feedback`, judge the learner's latest line (if there is none yet, set acceptable true and leave corrected and explanation empty). Set `finished` true when the goal is reached or after the learner's eighth line.\nConversation so far:\n\(history)"
    }

    static let liveOpening = "Begin the conversation now with your opening line."

    static func livePartner(_ s: RoleplayScenario) -> String {
        "You play \(s.partnerRole) in this scenario: \(s.setting) The learner plays \(s.userRole), named リン. Goal: \(s.goal). Speak only Japanese, as \(s.partnerRole), in one or two short sentences, in the register this scenario requires. Never correct the learner; stay in role."
    }

    static func reviewLine(scenario: RoleplayScenario, history: String) -> String {
        "Scenario: \(scenario.setting) The learner plays \(scenario.userRole), named リン, talking to \(scenario.partnerRole). Judge only リン's last line: is it natural Japanese with the correct keigo for this situation? `corrected` is the best version of that line.\nConversation so far:\n\(history)"
    }
}

public struct KaiwaAIService: AnswerJudging, Sendable {
    let client: LanguageModelClient
    let readings: JapaneseReading

    public init(client: LanguageModelClient, readings: JapaneseReading = JapaneseReading()) {
        self.client = client
        self.readings = readings
    }

    /// Calls `make` once more when fewer than half the requested items were valid, keeping both batches
    /// without duplicates (same `key`).
    private func atLeastHalf<T>(
        _ count: Int, key: (T) -> String, _ make: () async throws -> [T]
    ) async throws -> [T] {
        var items = try await make()
        if items.count * 2 < count, let more = try? await make() { items += more }
        var seen = Set<String>()
        items = items.filter { seen.insert(key($0)).inserted }
        guard !items.isEmpty else { throw KaiwaAIError.noValidItems }
        return Array(items.prefix(count))
    }

    private static func questionKey(_ q: QuizQuestion) -> String { q.promptBody + "→" + q.correctChoice }

    // MARK: Schemas

    static let judgementSchema: JSONSchema = .object(name: "judgement", properties: [
        JSONSchemaProperty("acceptable", .boolean(description: "True when the sentence is natural with correct keigo")),
        JSONSchemaProperty("corrected", .string(description: "The best version of the learner's sentence")),
        JSONSchemaProperty("explanation", .string(description: "English explanation, at most two sentences")),
    ])

    static func keigoSchema(count: Int) -> JSONSchema {
        .object(name: "keigoItems", properties: [
            JSONSchemaProperty("items", .array(
                items: .object(name: "keigoItem", properties: [
                    JSONSchemaProperty("situation", .string()),
                    JSONSchemaProperty("listener", .string(enumValues: Listener.allCases.map(\.rawValue))),
                    JSONSchemaProperty("target", .string(enumValues: KeigoLevel.allCases.map(\.rawValue))),
                    JSONSchemaProperty("plain", .string(description: "Casual sentence")),
                    JSONSchemaProperty("answer", .string(description: "Correct keigo sentence")),
                    JSONSchemaProperty("wrong", .array(items: .string(), minItems: 3, maxItems: 3)),
                    JSONSchemaProperty("explanation", .string()),
                ]),
                minItems: count, maxItems: count
            )),
        ])
    }

    static func uchiSotoSchema(count: Int) -> JSONSchema {
        .object(name: "uchiSotoItems", properties: [
            JSONSchemaProperty("items", .array(
                items: .object(name: "uchiSotoItem", properties: [
                    JSONSchemaProperty("situation", .string()),
                    JSONSchemaProperty("question", .string()),
                    JSONSchemaProperty("choices", .array(items: .string(), minItems: 4, maxItems: 4)),
                    JSONSchemaProperty("answerIndex", .integer(description: "0-based index into choices")),
                    JSONSchemaProperty("explanation", .string()),
                ]),
                minItems: count, maxItems: count
            )),
        ])
    }

    static func shadowingSchema(count: Int) -> JSONSchema {
        .object(name: "shadowingLines", properties: [
            JSONSchemaProperty("items", .array(
                items: .object(name: "shadowingLine", properties: [
                    JSONSchemaProperty("text", .string()),
                    JSONSchemaProperty("reading", .string(description: "Full hiragana reading")),
                    JSONSchemaProperty("meaning", .string()),
                ]),
                minItems: count, maxItems: count
            )),
        ])
    }

    static let partnerTurnSchema: JSONSchema = .object(name: "partnerTurn", properties: [
        JSONSchemaProperty("partnerLine", .string()),
        JSONSchemaProperty("feedback", judgementSchema),
        JSONSchemaProperty("finished", .boolean()),
    ])

    // MARK: Calls

    private func decode<T: Decodable>(_ type: T.Type, system: String = KaiwaPrompts.system, prompt: String, schema: JSONSchema) async throws -> T {
        let data = try await client.generateJSON(system: system, prompt: prompt, schema: schema)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw KaiwaAIError.invalidResponse
        }
    }

    public func judge(answer: String, question: QuizQuestion) async throws -> KeigoJudgement {
        try await decode(
            KeigoJudgement.self,
            prompt: KaiwaPrompts.judge(
                context: question.judgingContext ?? question.promptBody, accepted: question.acceptedAnswers, answer: answer
            ),
            schema: Self.judgementSchema
        )
    }

    private struct Items<T: Decodable>: Decodable { let items: [T] }

    private struct KeigoItem: Decodable {
        let situation: String, listener: String, target: String, plain: String, answer: String
        let wrong: [String], explanation: String
    }

    public func generateKeigoQuestions(count: Int) async throws -> [QuizQuestion] {
        try await atLeastHalf(count, key: Self.questionKey) { try await keigoBatch(count: count) }
    }

    private func keigoBatch(count: Int) async throws -> [QuizQuestion] {
        let items = try await decode(
            Items<KeigoItem>.self, prompt: KaiwaPrompts.keigoItems(count: count), schema: Self.keigoSchema(count: count)
        ).items
        return items.compactMap { item in
            let plain = item.plain.trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = item.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard JapaneseReading.isJapaneseSentence(plain), JapaneseReading.isJapaneseSentence(answer), plain != answer,
                  let target = KeigoLevel(rawValue: item.target) else { return nil }
            let listener = Listener(rawValue: item.listener) ?? .stranger
            let wrong = item.wrong.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let hasChoices = wrong.count == 3 && Set(wrong).count == 3 && !wrong.contains(answer)
                && wrong.allSatisfy(JapaneseReading.isJapaneseSentence)
            return QuizQuestion(
                id: .generated(.keigo), drill: .keigo,
                promptTitle: "To \(listener.label) · \(target.label)", promptBody: plain,
                choices: hasChoices ? ([answer] + wrong).shuffled() : [],
                correctChoice: answer, explanation: item.explanation,
                supportedModes: hasChoices ? [.choice, .typing] : [.typing],
                isSpeakable: true,
                judgingContext: "Situation: \(item.situation). Listener: \(listener.label). Say this in \(target.rawValue): \(plain)"
            )
        }
    }

    private struct UchiSotoGenerated: Decodable {
        let situation: String, question: String, choices: [String], answerIndex: Int, explanation: String
    }

    public func generateUchiSotoQuestions(count: Int) async throws -> [QuizQuestion] {
        try await atLeastHalf(count, key: Self.questionKey) { try await uchiSotoBatch(count: count) }
    }

    private func uchiSotoBatch(count: Int) async throws -> [QuizQuestion] {
        let items = try await decode(
            Items<UchiSotoGenerated>.self, prompt: KaiwaPrompts.uchiSotoItems(count: count),
            schema: Self.uchiSotoSchema(count: count)
        ).items
        return items.compactMap { item in
            guard item.choices.count == 4, Set(item.choices).count == 4, (0...3).contains(item.answerIndex),
                  item.choices.allSatisfy(JapaneseReading.isJapaneseSentence) else { return nil }
            return QuizQuestion(
                id: .generated(.uchiSoto), drill: .uchiSoto,
                promptTitle: item.situation, promptBody: item.question,
                choices: item.choices.shuffled(), correctChoice: item.choices[item.answerIndex],
                explanation: item.explanation, supportedModes: [.choice]
            )
        }
    }

    private struct ShadowingGenerated: Decodable { let text: String, reading: String, meaning: String }

    /// Readings come from `readings`, not the model, which often misreads kanji.
    public func generateShadowingLines(count: Int) async throws -> [ShadowingLine] {
        let lines = try await atLeastHalf(count, key: \.text) {
            let items = try await decode(
                Items<ShadowingGenerated>.self, prompt: KaiwaPrompts.shadowingLines(count: count),
                schema: Self.shadowingSchema(count: count)
            ).items
            return items.compactMap { item -> ShadowingLine? in
                let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard JapaneseReading.isJapaneseSentence(text) else { return nil }
                return ShadowingLine(id: "", text: text, reading: readings.hiragana(for: text), meaning: item.meaning)
            }
        }
        return lines.enumerated().map { index, line in
            ShadowingLine(id: "a\(index)", text: line.text, reading: line.reading, meaning: line.meaning)
        }
    }

    private static func transcript(_ history: [RoleplayViewModel.Line]) -> String {
        history.map { ($0.speaker == .partner ? "相手: " : "リン: ") + $0.text }.joined(separator: "\n")
    }

    /// Retries once when the model speaks as the learner (リン) instead of as the partner.
    public func partnerTurn(scenario: RoleplayScenario, history: [RoleplayViewModel.Line]) async throws -> PartnerTurn {
        let prompt = KaiwaPrompts.partnerTurn(scenario: scenario, history: Self.transcript(history))
        let first = try await decode(PartnerTurn.self, prompt: prompt, schema: Self.partnerTurnSchema)
        guard Self.speaksAsLearner(first.partnerLine) else { return first }
        let second = try await decode(
            PartnerTurn.self,
            prompt: prompt + "\nYour previous reply spoke as リン. Reply again as \(scenario.partnerRole) only.",
            schema: Self.partnerTurnSchema
        )
        guard !Self.speaksAsLearner(second.partnerLine) else { throw KaiwaAIError.invalidResponse }
        return second
    }

    static func speaksAsLearner(_ line: String) -> Bool {
        ["リンです", "リンと申します", "リンといいます"].contains { line.contains($0) }
    }

    /// Judges only the learner's last line, for sessions where a Live voice model plays the partner.
    public func reviewRoleplayLine(scenario: RoleplayScenario, history: [RoleplayViewModel.Line]) async throws -> KeigoJudgement {
        try await decode(
            KeigoJudgement.self, prompt: KaiwaPrompts.reviewLine(scenario: scenario, history: Self.transcript(history)),
            schema: Self.judgementSchema
        )
    }
}
