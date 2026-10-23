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
    static let system = "You are a Japanese keigo coach for a learner at JLPT N4–N3 level preparing to work in Japan. Write Japanese in natural kanji with standard okurigana. Write explanations in English, at most two sentences. Respond only with JSON that matches the schema."

    static func judge(context: String, accepted: [String], answer: String) -> String {
        """
        Situation: \(context)
        Model answers: \(accepted.joined(separator: " / "))
        Learner said: \(answer)
        Is the learner's sentence natural Japanese with the correct keigo for this situation? Small wording or particle differences are fine if the keigo is correct. `corrected` is the best version of the learner's sentence.
        """
    }

    static func keigoItems(count: Int) -> String {
        "Create \(count) varied workplace and service keigo exercises. Mix sonkeigo, kenjougo and teineigo. `plain` is the casual sentence, `answer` the correct keigo sentence, `wrong` exactly three typical mistakes (wrong direction, plain ます form, double keigo)."
    }

    static func uchiSotoItems(count: Int) -> String {
        "Create \(count) uchi/soto register-choice questions (talking about your own company's people to outsiders, phone calls, reception, family to teachers)."
    }

    static func shadowingLines(count: Int) -> String {
        "Create \(count) short, natural business keigo phrases for shadowing practice."
    }

    static func partnerTurn(scenario: RoleplayScenario, history: String) -> String {
        "Scenario: \(scenario.setting) You play: \(scenario.partnerRole). The learner plays: \(scenario.userRole), named リン. Goal: \(scenario.goal). Reply only as \(scenario.partnerRole), in one or two short sentences, in the register this scenario requires. In `feedback`, judge the learner's latest line (if there is none yet, set acceptable true and leave corrected and explanation empty). Set `finished` true when the goal is reached or after the learner's eighth line.\nConversation so far:\n\(history)"
    }
}

public struct KaiwaAIService: AnswerJudging, Sendable {
    let client: LanguageModelClient

    public init(client: LanguageModelClient) { self.client = client }

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
        let items = try await decode(
            Items<KeigoItem>.self, prompt: KaiwaPrompts.keigoItems(count: count), schema: Self.keigoSchema(count: count)
        ).items
        let questions: [QuizQuestion] = items.compactMap { item in
            let plain = item.plain.trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = item.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty, !answer.isEmpty, let target = KeigoLevel(rawValue: item.target) else { return nil }
            let listener = Listener(rawValue: item.listener) ?? .stranger
            let wrong = item.wrong.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let hasChoices = wrong.count == 3 && Set(wrong).count == 3 && !wrong.contains(answer)
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
        guard !questions.isEmpty else { throw KaiwaAIError.noValidItems }
        return questions
    }

    private struct UchiSotoGenerated: Decodable {
        let situation: String, question: String, choices: [String], answerIndex: Int, explanation: String
    }

    public func generateUchiSotoQuestions(count: Int) async throws -> [QuizQuestion] {
        let items = try await decode(
            Items<UchiSotoGenerated>.self, prompt: KaiwaPrompts.uchiSotoItems(count: count),
            schema: Self.uchiSotoSchema(count: count)
        ).items
        let questions: [QuizQuestion] = items.compactMap { item in
            guard item.choices.count == 4, Set(item.choices).count == 4, (0...3).contains(item.answerIndex) else { return nil }
            return QuizQuestion(
                id: .generated(.uchiSoto), drill: .uchiSoto,
                promptTitle: item.situation, promptBody: item.question,
                choices: item.choices.shuffled(), correctChoice: item.choices[item.answerIndex],
                explanation: item.explanation, supportedModes: [.choice]
            )
        }
        guard !questions.isEmpty else { throw KaiwaAIError.noValidItems }
        return questions
    }

    private struct ShadowingGenerated: Decodable { let text: String, reading: String, meaning: String }

    public func generateShadowingLines(count: Int) async throws -> [ShadowingLine] {
        let items = try await decode(
            Items<ShadowingGenerated>.self, prompt: KaiwaPrompts.shadowingLines(count: count),
            schema: Self.shadowingSchema(count: count)
        ).items
        let lines = items.enumerated().compactMap { index, item -> ShadowingLine? in
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return ShadowingLine(id: "a\(index)", text: text, reading: item.reading, meaning: item.meaning)
        }
        guard !lines.isEmpty else { throw KaiwaAIError.noValidItems }
        return lines
    }

    public func partnerTurn(scenario: RoleplayScenario, history: [RoleplayViewModel.Line]) async throws -> PartnerTurn {
        let transcript = history.map { ($0.speaker == .partner ? "相手: " : "リン: ") + $0.text }.joined(separator: "\n")
        return try await decode(
            PartnerTurn.self, prompt: KaiwaPrompts.partnerTurn(scenario: scenario, history: transcript),
            schema: Self.partnerTurnSchema
        )
    }
}
