import Foundation
import Testing
@testable import KachiiroCore

// MARK: Fakes

final class FakeLanguageModelClient: LanguageModelClient, @unchecked Sendable {
    enum Reply { case json(String), failure(Error) }

    private let lock = NSLock()
    private var replies: [Reply]
    private var _prompts: [String] = []
    private var _schemas: [JSONSchema] = []

    init(_ replies: [Reply]) { self.replies = replies }
    convenience init(json: String) { self.init([.json(json)]) }

    var prompts: [String] { lock.withLock { _prompts } }
    var schemas: [JSONSchema] { lock.withLock { _schemas } }

    func generateJSON(system: String, prompt: String, schema: JSONSchema) async throws -> Data {
        let reply: Reply = lock.withLock {
            _prompts.append(prompt)
            _schemas.append(schema)
            return replies.count > 1 ? replies.removeFirst() : replies[0]
        }
        switch reply {
        case .json(let text): return Data(text.utf8)
        case .failure(let error): throw error
        }
    }
}

struct FakeJudge: AnswerJudging {
    var result: Result<KeigoJudgement, Error>
    func judge(answer: String, question: QuizQuestion) async throws -> KeigoJudgement { try result.get() }
}

struct JudgeFailure: Error, LocalizedError {
    var errorDescription: String? { "boom" }
}

@MainActor
func makeSettingsViewModel(
    store: InMemorySettingsStore, repository: InMemoryProgressRepository, keys: InMemoryAPIKeyStore? = nil
) -> SettingsViewModel {
    let keys = keys ?? InMemoryAPIKeyStore()
    return SettingsViewModel(
        store: store, repository: repository, keys: keys,
        aiResolver: KaiwaAIResolver(
            settings: store, keys: keys, appleAvailability: { .unavailable("requires iOS 26") }, makeAppleClient: { nil }
        )
    )
}

private let acceptJudgement = KeigoJudgement(acceptable: true, corrected: "better", explanation: "fine")

// MARK: Schema and Gemini

@Suite struct JSONSchemaAndGeminiTests {
    @Test func objectSchemaRequiresEveryProperty() throws {
        let data = KaiwaAIService.keigoSchema(count: 5).jsonObjectData()
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let items = try #require((root["properties"] as? [String: Any])?["items"] as? [String: Any])
        #expect(items["minItems"] as? Int == 5 && items["maxItems"] as? Int == 5)
        let item = try #require(items["items"] as? [String: Any])
        #expect(item["required"] as? [String] == ["situation", "listener", "target", "plain", "answer", "wrong", "explanation"])
        let target = try #require((item["properties"] as? [String: Any])?["target"] as? [String: Any])
        #expect(target["enum"] as? [String] == ["sonkeigo", "kenjougo", "teineigo"])
    }

    @Test func requestTargetsGeminiWithKeyHeaderAndJSONFormat() throws {
        let client = GeminiClient(apiKey: "KEY")
        let request = client.makeRequest(system: "sys", prompt: "go", schema: KaiwaAIService.judgementSchema)
        #expect(request.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "KEY")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let bodyData = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let text = ((body["generationConfig"] as? [String: Any])?["responseFormat"] as? [String: Any])?["text"] as? [String: Any]
        #expect(text?["mimeType"] as? String == "APPLICATION_JSON")
        #expect((text?["schema"] as? [String: Any])?["type"] as? String == "object")
        let contents = try #require(body["contents"] as? [[String: Any]])
        #expect(((contents[0]["parts"] as? [[String: Any]])?[0]["text"]) as? String == "go")
    }

    @Test func parsesSuccessResponseText() throws {
        let canned = #"{"candidates":[{"content":{"parts":[{"text":"{\"a\":"},{"text":"1}"}]}}]}"#
        let data = try GeminiClient.parse(data: Data(canned.utf8), status: 200)
        #expect(String(decoding: data, as: UTF8.self) == #"{"a":1}"#)
    }

    @Test func errorBodyMapsToHTTPError() {
        let canned = #"{"error":{"code":400,"message":"API key not valid"}}"#
        #expect(throws: KaiwaAIError.http(status: 400, message: "API key not valid")) {
            try GeminiClient.parse(data: Data(canned.utf8), status: 400)
        }
        #expect(throws: KaiwaAIError.http(status: 500, message: "Unknown error")) {
            try GeminiClient.parse(data: Data("oops".utf8), status: 500)
        }
    }

    @Test func emptyCandidatesIsInvalidResponse() {
        #expect(throws: KaiwaAIError.invalidResponse) {
            try GeminiClient.parse(data: Data(#"{"candidates":[]}"#.utf8), status: 200)
        }
    }
}

// MARK: Service

@Suite struct KaiwaAIServiceTests {
    private func service(_ json: String) -> (KaiwaAIService, FakeLanguageModelClient) {
        let client = FakeLanguageModelClient(json: json)
        return (KaiwaAIService(client: client), client)
    }

    @Test func judgeDecodesAndPromptCarriesContext() async throws {
        let (svc, client) = service(#"{"acceptable":true,"corrected":"部長はいらっしゃいます","explanation":"Good."}"#)
        let q = QuizQuestion(
            id: .generated(.keigo), drill: .keigo, promptTitle: "t", promptBody: "b", choices: [], correctChoice: "x",
            acceptedAnswers: ["x", "y"], supportedModes: [.typing], judgingContext: "CTX"
        )
        let verdict = try await svc.judge(answer: "ANSWER", question: q)
        #expect(verdict.acceptable && verdict.corrected == "部長はいらっしゃいます")
        let prompt = try #require(client.prompts.first)
        #expect(prompt.contains("CTX") && prompt.contains("ANSWER") && prompt.contains("x / y"))
    }

    @Test func malformedJSONIsInvalidResponse() async {
        let (svc, _) = service("not json")
        await #expect(throws: KaiwaAIError.invalidResponse) {
            try await svc.judge(answer: "a", question: QuizQuestion(
                id: .generated(.keigo), drill: .keigo, promptTitle: "", promptBody: "", choices: [], correctChoice: "x"
            ))
        }
    }

    @Test func keigoGenerationKeepsValidItemsAndDowngradesShortWrongLists() async throws {
        let json = """
        {"items":[
          {"situation":"s","listener":"boss","target":"sonkeigo","plain":"部長は来る？","answer":"部長はいらっしゃいますか","wrong":["部長は参りますか","部長は来ますか","部長はいらっしゃられますか"],"explanation":"e"},
          {"situation":"s","listener":"nonsense","target":"kenjougo","plain":"私が行く","answer":"私が参ります","wrong":["私がいらっしゃいます","私が行きます"],"explanation":"e"},
          {"situation":"s","listener":"boss","target":"kenjougo","plain":"","answer":"x","wrong":["a","b","c"],"explanation":"e"}
        ]}
        """
        let (svc, _) = service(json)
        let qs = try await svc.generateKeigoQuestions(count: 3)
        #expect(qs.count == 2)
        #expect(qs.allSatisfy { $0.id.raw.hasPrefix("ai:") && $0.id.isGenerated && $0.isSpeakable && $0.judgingContext != nil })
        #expect(qs[0].supportedModes == [.choice, .typing] && qs[0].choices.count == 4)
        #expect(qs[1].supportedModes == [.typing] && qs[1].choices.isEmpty)
        FactoryTestSupport.expectWellFormed(qs, KeigoQuestionFactory())
    }

    @Test func allInvalidItemsThrowNoValidItems() async {
        let (svc, _) = service(#"{"items":[{"situation":"s","listener":"boss","target":"bogus","plain":"p","answer":"a","wrong":[],"explanation":"e"}]}"#)
        await #expect(throws: KaiwaAIError.noValidItems) { try await svc.generateKeigoQuestions(count: 1) }
    }

    @Test func uchiSotoItemsNeedFourDistinctChoicesAndValidIndex() async throws {
        let json = """
        {"items":[
          {"situation":"s","question":"q","choices":["a","b","c","d"],"answerIndex":2,"explanation":"e"},
          {"situation":"s","question":"q","choices":["a","a","c","d"],"answerIndex":0,"explanation":"e"},
          {"situation":"s","question":"q","choices":["a","b","c","d"],"answerIndex":4,"explanation":"e"}
        ]}
        """
        let (svc, _) = service(json)
        let qs = try await svc.generateUchiSotoQuestions(count: 3)
        #expect(qs.count == 1)
        #expect(qs[0].correctChoice == "c" && qs[0].supportedModes == [.choice] && qs[0].id.isGenerated)
        FactoryTestSupport.expectWellFormed(qs, UchiSotoQuestionFactory())
    }

    @Test func shadowingLinesGetAIIdsAndNoPitch() async throws {
        let (svc, _) = service(#"{"items":[{"text":"失礼いたします","reading":"しつれいいたします","meaning":"Excuse me"},{"text":" ","reading":"","meaning":""}]}"#)
        let lines = try await svc.generateShadowingLines(count: 2)
        #expect(lines.map(\.id) == ["a0"] && lines[0].pitch == nil)
    }

    @MainActor
    @Test func partnerTurnPromptCarriesHistory() async throws {
        let (svc, client) = service(#"{"partnerLine":"はい","feedback":{"acceptable":true,"corrected":"","explanation":""},"finished":false}"#)
        let scenario = RoleplayScenario.bundled[0]
        let vm = RoleplayViewModel(scenario: scenario)
        await vm.start()
        await vm.submit("リンと申します")
        let turn = try await svc.partnerTurn(scenario: scenario, history: vm.lines)
        #expect(turn.partnerLine == "はい" && !turn.finished)
        let prompt = try #require(client.prompts.first)
        #expect(prompt.contains("相手: ") && prompt.contains("リン: リンと申します") && prompt.contains(scenario.goal))
    }
}

// MARK: Resolver

@MainActor
@Suite struct KaiwaAIResolverTests {
    private func make(
        engine: KaiwaEngine, content: KaiwaContentSource = .bundled, key: String? = nil,
        apple: EngineAvailability = .unavailable("requires iOS 26")
    ) -> KaiwaAIResolver {
        let settings = InMemorySettingsStore()
        settings.kaiwaEngine = engine
        settings.kaiwaContent = content
        return KaiwaAIResolver(
            settings: settings, keys: InMemoryAPIKeyStore(key: key), appleAvailability: { apple },
            makeAppleClient: { FakeLanguageModelClient(json: "{}") },
            makeGeminiClient: { _ in FakeLanguageModelClient(json: "{}") }
        )
    }

    @Test func rulesNeverUsesAI() {
        let r = make(engine: .rules)
        #expect(r.service() == nil && !r.usesGeneratedContent && r.notice == nil)
        #expect(r.availability(of: .rules) == .available)
    }

    @Test func rulesWithGeneratedContentExplainsFallback() {
        #expect(make(engine: .rules, content: .generated).notice == "AI-generated content needs Apple Intelligence or Gemini. Using bundled content.")
    }

    @Test func geminiNeedsANonBlankKey() {
        #expect(make(engine: .gemini).availability(of: .gemini) == .unavailable("add a Gemini API key in Settings"))
        #expect(make(engine: .gemini, key: "  ").service() == nil)
        let ready = make(engine: .gemini, content: .generated, key: " K ")
        #expect(ready.service() != nil && ready.usesGeneratedContent && ready.notice == nil)
        #expect(make(engine: .gemini, content: .bundled, key: "K").usesGeneratedContent == false)
    }

    @Test func unavailableAppleFallsBackWithNotice() {
        let r = make(engine: .appleIntelligence, content: .generated)
        #expect(r.service() == nil && !r.usesGeneratedContent)
        #expect(r.notice == "Apple Intelligence (on-device) unavailable: requires iOS 26. Using offline rules and bundled content.")
    }

    @Test func availableAppleProvidesService() {
        let r = make(engine: .appleIntelligence, content: .generated, apple: .available)
        #expect(r.service() != nil && r.usesGeneratedContent && r.notice == nil)
    }
}

// MARK: Quiz session judging

@MainActor
@Suite struct QuizJudgingTests {
    private func question(id: ItemKey = .keigoSentence(1), context: String? = "ctx") -> QuizQuestion {
        QuizQuestion(
            id: id, drill: .keigo, promptTitle: "t", promptBody: "b", choices: [], correctChoice: "正解",
            supportedModes: [.typing], judgingContext: context
        )
    }

    @Test func acceptingJudgeTurnsMissIntoCorrectAndRecordsOnce() async {
        let repo = InMemoryProgressRepository()
        let vm = QuizSessionViewModel(
            questions: [question()], initialMode: .typing, repository: repo,
            judge: FakeJudge(result: .success(acceptJudgement))
        )
        vm.submitText("別の答え")
        #expect(vm.isJudging && vm.result == nil)
        await vm.pendingJudgement?.value
        #expect(!vm.isJudging && vm.result == .correct && vm.judgement == acceptJudgement)
        #expect(repo.attempts.count == 1 && repo.attempts[0].correct)
    }

    @Test func throwingJudgeMarksWrongWithError() async {
        let vm = QuizSessionViewModel(
            questions: [question()], initialMode: .typing, repository: InMemoryProgressRepository(),
            judge: FakeJudge(result: .failure(JudgeFailure()))
        )
        vm.submitText("x")
        await vm.pendingJudgement?.value
        #expect(vm.result == .wrong(correctAnswer: "正解"))
        #expect(vm.judgeError == "AI check failed: boom")
        vm.next()
        #expect(vm.judgeError == nil && vm.judgement == nil)
    }

    @Test func noJudgeOrNoContextMeansNoTask() {
        let a = QuizSessionViewModel(questions: [question()], initialMode: .typing, repository: InMemoryProgressRepository())
        a.submitText("x")
        #expect(a.pendingJudgement == nil && a.result == .wrong(correctAnswer: "正解"))
        let b = QuizSessionViewModel(
            questions: [question(context: nil)], initialMode: .typing, repository: InMemoryProgressRepository(),
            judge: FakeJudge(result: .success(acceptJudgement))
        )
        b.submitText("x")
        #expect(b.pendingJudgement == nil && !b.isJudging)
    }

    @Test func exactMatchSkipsTheJudge() {
        let vm = QuizSessionViewModel(
            questions: [question()], initialMode: .typing, repository: InMemoryProgressRepository(),
            judge: FakeJudge(result: .failure(JudgeFailure()))
        )
        vm.submitText("正解。")
        #expect(vm.result == .correct && vm.pendingJudgement == nil)
    }

    @Test func generatedKeysAreNeverRecorded() {
        let repo = InMemoryProgressRepository()
        let vm = QuizSessionViewModel(questions: [question(id: .generated(.keigo))], initialMode: .typing, repository: repo)
        vm.submitText("正解")
        #expect(vm.result == .correct && repo.attempts.isEmpty)
    }

    @Test func inputIsIgnoredWhileJudging() async {
        let q = QuizQuestion(
            id: .keigoSentence(2), drill: .keigo, promptTitle: "t", promptBody: "b", choices: ["正解", "a", "b", "c"],
            correctChoice: "正解", judgingContext: "ctx"
        )
        let vm = QuizSessionViewModel(
            questions: [q, question()], initialMode: .typing, repository: InMemoryProgressRepository(),
            judge: FakeJudge(result: .success(acceptJudgement))
        )
        vm.submitText("違う")
        vm.submitChoice("正解")
        vm.next()
        #expect(vm.isJudging && vm.answers.isEmpty && vm.index == 0)
        await vm.pendingJudgement?.value
        #expect(vm.answers.count == 1)
    }
}

// MARK: Practice generation

@MainActor
@Suite struct PracticeGenerationTests {
    private func resolver(json: String, content: KaiwaContentSource = .generated) -> (KaiwaAIResolver, InMemorySettingsStore) {
        let settings = InMemorySettingsStore()
        settings.kaiwaEngine = .gemini
        settings.kaiwaContent = content
        let r = KaiwaAIResolver(
            settings: settings, keys: InMemoryAPIKeyStore(key: "k"), appleAvailability: { .available }, makeAppleClient: { nil },
            makeGeminiClient: { _ in FakeLanguageModelClient(json: json) }
        )
        return (r, settings)
    }

    @Test func generatedSessionUsesAIQuestionsAndJudge() async throws {
        let json = #"{"items":[{"situation":"s","question":"q","choices":["a","b","c","d"],"answerIndex":1,"explanation":"e"}]}"#
        let (r, settings) = resolver(json: json)
        let vm = PracticeViewModel(seed: TestSeed.shared, settings: settings, repository: InMemoryProgressRepository(), aiResolver: r)
        #expect(vm.usesGeneratedContent(for: .keigo) && !vm.usesGeneratedContent(for: .vocab))
        let session = try #require(await vm.makeGeneratedSession(for: .uchiSoto))
        #expect(session.total == 1 && session.questions[0].correctChoice == "b")
        #expect(!vm.isGenerating)
    }

    @Test func generationFailureSetsMessage() async {
        let (r, settings) = resolver(json: #"{"items":[]}"#)
        let vm = PracticeViewModel(seed: TestSeed.shared, settings: settings, repository: InMemoryProgressRepository(), aiResolver: r)
        let session = await vm.makeGeneratedSession(for: .keigo)
        #expect(session == nil)
        #expect(vm.message == "Couldn't generate questions: The AI did not return usable items.")
    }

    @Test func bundledContentDoesNotUseGeneration() {
        let (r, settings) = resolver(json: "{}", content: .bundled)
        let vm = PracticeViewModel(seed: TestSeed.shared, settings: settings, repository: InMemoryProgressRepository(), aiResolver: r)
        #expect(!vm.usesGeneratedContent(for: .keigo))
    }
}

// MARK: Roleplay AI

@MainActor
@Suite struct RoleplayAITests {
    private let scenario = RoleplayScenario.bundled.first { $0.id == "phone-company" }!

    @Test func scriptedJudgeAcceptsUnrecognisedReplyAndContinues() async {
        let vm = RoleplayViewModel(scenario: scenario, mode: .scripted(judge: FakeJudge(result: .success(acceptJudgement))))
        await vm.start()
        await vm.submit("リンです、田中部長いますか")
        #expect(vm.lines[1].verdict == .reviewed(acceptable: true, corrected: "better", explanation: "fine"))
        #expect(vm.lines.last?.text == scenario.turn("t2")?.partner)
        #expect(vm.passedCount == 1 && !vm.isWaiting)
    }

    @Test func scriptedJudgeRejectionStillContinuesButIsNotPassed() async {
        let no = KeigoJudgement(acceptable: false, corrected: "c", explanation: "e")
        let vm = RoleplayViewModel(scenario: scenario, mode: .scripted(judge: FakeJudge(result: .success(no))))
        await vm.start()
        await vm.submit("田中さんいる？")
        #expect(vm.lines[1].verdict == .reviewed(acceptable: false, corrected: "c", explanation: "e"))
        #expect(vm.passedCount == 0 && vm.lines.count == 3)
    }

    @Test func scriptedJudgeErrorFallsBackToFailedAndReportsError() async {
        let vm = RoleplayViewModel(scenario: scenario, mode: .scripted(judge: FakeJudge(result: .failure(JudgeFailure()))))
        await vm.start()
        await vm.submit("田中さんいる？")
        guard case .failed? = vm.lines[1].verdict else { Issue.record("expected .failed"); return }
        #expect(vm.errorMessage == "AI check failed: boom")
    }

    @Test func matchingReplySkipsTheJudge() async {
        let vm = RoleplayViewModel(scenario: scenario, mode: .scripted(judge: FakeJudge(result: .failure(JudgeFailure()))))
        await vm.start()
        await vm.submit("リンと申しますが、田中部長はいらっしゃいますか")
        #expect(vm.errorMessage == nil)
        guard case .passed? = vm.lines[1].verdict else { Issue.record("expected .passed"); return }
    }

    private func turnJSON(_ line: String, finished: Bool = false, ok: Bool = true) -> String {
        #"{"partnerLine":"\#(line)","feedback":{"acceptable":\#(ok),"corrected":"c","explanation":"e"},"finished":\#(finished)}"#
    }

    @Test func freeModeAttachesFeedbackAndFinishes() async {
        let client = FakeLanguageModelClient([.json(turnJSON("はい、ABC商事です")), .json(turnJSON("少々お待ちください")), .json(turnJSON("ありがとうございました", finished: true))])
        let vm = RoleplayViewModel(scenario: scenario, mode: .free(KaiwaAIService(client: client)))
        await vm.start()
        #expect(vm.lines.map(\.text) == ["はい、ABC商事です"] && vm.currentHint == scenario.goal && vm.modelAnswer == nil)
        await vm.submit("リンと申します")
        #expect(vm.lines[1].verdict == .reviewed(acceptable: true, corrected: "c", explanation: "e"))
        #expect(vm.lines.last?.text == "少々お待ちください" && !vm.isFinished)
        await vm.submit("田中部長をお願いします")
        #expect(vm.isFinished && vm.passedCount == 2)
        #expect(client.prompts[2].contains("リン: 田中部長をお願いします") && client.prompts[2].contains("相手: 少々お待ちください"))
    }

    @Test func freeModeRetryResendsSameHistoryAfterError() async {
        let client = FakeLanguageModelClient([.json(turnJSON("はい")), .failure(JudgeFailure()), .json(turnJSON("どうぞ"))])
        let vm = RoleplayViewModel(scenario: scenario, mode: .free(KaiwaAIService(client: client)))
        await vm.start()
        await vm.submit("もしもし")
        #expect(vm.errorMessage == "boom" && vm.canRetry && vm.lines.count == 2)
        await vm.retryLast()
        #expect(vm.errorMessage == nil && !vm.canRetry && vm.lines.map(\.text) == ["はい", "もしもし", "どうぞ"])
        #expect(client.prompts[1] == client.prompts[2])
    }

    @Test func freeModeStopsAfterEightLearnerLines() async {
        let client = FakeLanguageModelClient([.json(turnJSON("次"))])
        let vm = RoleplayViewModel(scenario: scenario, mode: .free(KaiwaAIService(client: client)))
        await vm.start()
        for i in 1...8 { await vm.submit("発話\(i)") }
        #expect(vm.isFinished && vm.userTurnCount == 8)
    }
}

// MARK: Shadowing generation and settings

@MainActor
@Suite struct ShadowingAndSettingsTests {
    private let bundled = [ShadowingLine(id: "k1", text: "失礼します", reading: nil, meaning: "m")]

    @Test func generatorFailureKeepsBundledLines() async {
        let service = KaiwaAIService(client: FakeLanguageModelClient([.failure(JudgeFailure())]))
        let vm = ShadowingViewModel(lines: bundled, generator: service)
        await vm.load()
        #expect(vm.lines == bundled)
        #expect(vm.errorMessage == "Couldn't generate lines: boom. Showing bundled lines.")
    }

    @Test func generatorSuccessReplacesLines() async {
        let service = KaiwaAIService(client: FakeLanguageModelClient(json: #"{"items":[{"text":"承知いたしました","reading":"しょうちいたしました","meaning":"Understood"}]}"#))
        let vm = ShadowingViewModel(lines: bundled, generator: service)
        await vm.load()
        #expect(vm.lines.map(\.text) == ["承知いたしました"] && vm.errorMessage == nil)
    }

    @Test func engineAndContentPersistThroughTheStore() {
        let store = InMemorySettingsStore()
        let vm = makeSettingsViewModel(store: store, repository: InMemoryProgressRepository())
        #expect(vm.kaiwaEngine == .rules && vm.kaiwaContent == .bundled && !vm.isContentPickerEnabled)
        vm.setKaiwaEngine(.gemini)
        vm.setKaiwaContent(.generated)
        #expect(store.kaiwaEngine == .gemini && store.kaiwaContent == .generated && vm.isContentPickerEnabled)
    }

    @Test func geminiKeySaveTrimsAndRejectsBlank() {
        let keys = InMemoryAPIKeyStore()
        let vm = makeSettingsViewModel(store: InMemorySettingsStore(), repository: InMemoryProgressRepository(), keys: keys)
        #expect(!vm.saveGeminiKey("  \n") && keys.geminiKey() == nil && !vm.hasGeminiKey)
        #expect(vm.saveGeminiKey("  abc ") && keys.geminiKey() == "abc" && vm.hasGeminiKey)
        #expect(vm.availability(of: .gemini) == .available)
        vm.removeGeminiKey()
        #expect(keys.geminiKey() == nil && !vm.hasGeminiKey)
    }
}
