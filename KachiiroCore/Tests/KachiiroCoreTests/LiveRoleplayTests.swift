import Foundation
import Testing
@testable import KachiiroCore

@MainActor
final class FakeLivePartner: LiveRoleplayPartner {
    var transcripts: [String]
    var failNext = false
    private(set) var historyCounts: [Int] = []
    private(set) var closeCount = 0

    init(_ transcripts: [String]) { self.transcripts = transcripts }

    func reply(
        system: String, history: [RoleplayViewModel.Line], onAudio: @escaping @MainActor (Data) -> Void
    ) async throws -> String {
        historyCounts.append(history.count)
        if failNext {
            failNext = false
            throw JudgeFailure()
        }
        onAudio(Data([1, 2]))
        return transcripts.count > 1 ? transcripts.removeFirst() : transcripts[0]
    }

    func close() { closeCount += 1 }
}

@MainActor
final class FakePCM: PCMAudioStreaming {
    private(set) var chunks: [(Data, Double)] = []
    private(set) var stopCount = 0
    func enqueue(_ pcm16: Data, sampleRate: Double) { chunks.append((pcm16, sampleRate)) }
    func stop() { stopCount += 1 }
}

@Suite struct GeminiLiveWireTests {
    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func setupAsksForJapaneseAudioWithTranscript() throws {
        let setup = try #require(try object(GeminiLiveClient.setupMessage(system: "sys"))["setup"] as? [String: Any])
        #expect(setup["model"] as? String == "models/gemini-3.1-flash-live-preview")
        let config = try #require(setup["generationConfig"] as? [String: Any])
        #expect(config["responseModalities"] as? [String] == ["AUDIO"])
        #expect(setup["outputAudioTranscription"] != nil)
    }

    @Test func turnMessageCompletesTheTurn() throws {
        let content = try #require(
            try object(GeminiLiveClient.turnMessage([("user", "a"), ("model", "b")]))["clientContent"] as? [String: Any]
        )
        #expect(content["turnComplete"] as? Bool == true)
        #expect((content["turns"] as? [[String: Any]])?.map { $0["role"] as? String } == ["user", "model"])
    }

    @Test func urlCarriesPercentEncodedKey() {
        let url = GeminiLiveClient.url(apiKey: "a&b=c")
        #expect(url.scheme == "wss" && url.query == "key=a%26b%3Dc")
    }

    @Test func parseKeepsAudioAndTranscriptFromOneFrame() {
        let frame = #"{"serverContent":{"modelTurn":{"parts":[{"inlineData":{"mimeType":"audio/pcm;rate=24000","data":"AAE="}}]},"outputTranscription":{"text":"はい"}}}"#
        #expect(GeminiLiveClient.parse(Data(frame.utf8)) == [.audio(Data([0, 1])), .transcript("はい")])
        #expect(GeminiLiveClient.parse(Data(#"{"serverContent":{"turnComplete":true}}"#.utf8)) == [.turnComplete])
        #expect(GeminiLiveClient.parse(Data(#"{"setupComplete":{}}"#.utf8)) == [.setupComplete])
        #expect(GeminiLiveClient.parse(Data(#"{"serverContent":{}}"#.utf8)) == [.other])
        #expect(GeminiLiveClient.parse(Data("nope".utf8)) == [.other])
    }
}

@MainActor
@Suite struct LiveRoleplayTests {
    private let scenario = RoleplayScenario.bundled.first { $0.id == "phone-company" }!
    private let reviewJSON = #"{"acceptable":true,"corrected":"c","explanation":"e"}"#

    private func make(
        _ partner: FakeLivePartner, review: FakeLanguageModelClient? = nil, speech: SpySpeech? = nil
    ) -> (RoleplayViewModel, FakePCM) {
        let pcm = FakePCM()
        let reviewer = KaiwaAIService(client: review ?? FakeLanguageModelClient(json: reviewJSON))
        let vm = RoleplayViewModel(
            scenario: scenario, mode: .live(partner: partner, reviewer: reviewer, audio: pcm), speech: speech
        )
        return (vm, pcm)
    }

    @Test func startShowsTranscriptAndStreamsAudioWithoutTTS() async {
        let speech = SpySpeech()
        let (vm, pcm) = make(FakeLivePartner(["はい、ABC商事です"]), speech: speech)
        await vm.start()
        #expect(vm.lines.map(\.text) == ["はい、ABC商事です"] && vm.isLiveMode && vm.isFreeMode)
        #expect(pcm.chunks.count == 1 && pcm.chunks[0].1 == 24_000)
        #expect(speech.spoken.isEmpty && vm.currentHint == scenario.goal && vm.modelAnswer == nil)
    }

    @Test func submitRepliesAndReviewsTheLearnerLine() async {
        let partner = FakeLivePartner(["はい", "少々お待ちください"])
        let (vm, _) = make(partner)
        await vm.start()
        await vm.submit("リンと申します")
        await vm.pendingReview?.value
        #expect(vm.lines.map(\.text) == ["はい", "リンと申します", "少々お待ちください"])
        #expect(vm.lines[1].verdict == .reviewed(acceptable: true, corrected: "c", explanation: "e"))
        #expect(partner.historyCounts == [0, 2])
    }

    @Test func partnerFailureAllowsRetry() async {
        let partner = FakeLivePartner(["はい", "どうぞ"])
        let (vm, _) = make(partner)
        await vm.start()
        partner.failNext = true
        await vm.submit("もしもし")
        #expect(vm.errorMessage == "boom" && vm.canRetry && vm.lines.count == 2)
        await vm.retryLast()
        #expect(vm.errorMessage == nil && !vm.canRetry && vm.lines.map(\.text) == ["はい", "もしもし", "どうぞ"])
    }

    @Test func reviewFailureNeitherBlocksNorRetries() async {
        let review = FakeLanguageModelClient([.failure(JudgeFailure())])
        let (vm, _) = make(FakeLivePartner(["はい", "どうぞ"]), review: review)
        await vm.start()
        await vm.submit("もしもし")
        await vm.pendingReview?.value
        #expect(vm.lines[1].verdict == nil && !vm.canRetry && vm.errorMessage == nil && vm.lines.count == 3)
    }

    @Test func stopsAfterEightLearnerLinesAndClosesTheSession() async {
        let partner = FakeLivePartner(["次"])
        let (vm, _) = make(partner)
        await vm.start()
        let closesBefore = partner.closeCount
        for i in 1...8 { await vm.submit("発話\(i)") }
        #expect(vm.isFinished && vm.userTurnCount == 8 && partner.closeCount == closesBefore + 1)
    }

    @Test func endClosesTheSessionAndSilencesAudio() async {
        let partner = FakeLivePartner(["はい"])
        let (vm, pcm) = make(partner)
        await vm.start()
        let stops = pcm.stopCount
        let closes = partner.closeCount
        vm.stopPartnerAudio()
        vm.end()
        #expect(pcm.stopCount == stops + 2 && partner.closeCount == closes + 1)
    }
}

@MainActor
@Suite struct LiveResolverTests {
    private func resolver(engine: KaiwaEngine, content: KaiwaContentSource, key: String? = "k") -> KaiwaAIResolver {
        let settings = InMemorySettingsStore()
        settings.kaiwaEngine = engine
        settings.kaiwaContent = content
        return KaiwaAIResolver(
            settings: settings, keys: InMemoryAPIKeyStore(key: key), appleAvailability: { .available },
            makeAppleClient: { FakeLanguageModelClient(json: "{}") },
            makeGeminiClient: { _ in FakeLanguageModelClient(json: "{}") },
            makeGeminiLive: { _ in FakeLivePartner(["x"]) }
        )
    }

    @Test func liveNeedsGeminiGeneratedContentAndKey() {
        #expect(resolver(engine: .gemini, content: .generated).liveRoleplayPartner() != nil)
        #expect(resolver(engine: .gemini, content: .bundled).liveRoleplayPartner() == nil)
        #expect(resolver(engine: .appleIntelligence, content: .generated).liveRoleplayPartner() == nil)
        #expect(resolver(engine: .gemini, content: .generated, key: "  ").liveRoleplayPartner() == nil)
    }
}
