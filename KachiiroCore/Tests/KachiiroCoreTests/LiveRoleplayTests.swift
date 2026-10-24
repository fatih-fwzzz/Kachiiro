import Foundation
import Testing
@testable import KachiiroCore

@MainActor
final class FakeLivePartner: LiveRoleplayPartner {
    var failConnect = false
    private let opening: [LiveEvent]
    private var continuation: AsyncThrowingStream<LiveEvent, Error>.Continuation?
    private(set) var connectHistoryCounts: [Int] = []
    private(set) var sentTexts: [String] = []
    private(set) var sentAudio: [Data] = []
    private(set) var closeCount = 0

    init(opening: [LiveEvent] = []) { self.opening = opening }

    func connect(system: String, history: [RoleplayViewModel.Line]) async throws -> AsyncThrowingStream<LiveEvent, Error> {
        connectHistoryCounts.append(history.count)
        if failConnect {
            failConnect = false
            throw JudgeFailure()
        }
        let (stream, continuation) = AsyncThrowingStream<LiveEvent, Error>.makeStream()
        self.continuation = continuation
        for event in opening { continuation.yield(event) }
        return stream
    }

    func sendAudio(_ pcm16: Data) { sentAudio.append(pcm16) }
    func sendText(_ text: String) { sentTexts.append(text) }

    func close() {
        closeCount += 1
        continuation?.finish()
    }

    func endSession(throwing error: Error? = nil) { continuation?.finish(throwing: error) }
}

@MainActor
final class FakeAudioIO: LiveAudioIO {
    var startError: Error?
    private(set) var onChunk: (@MainActor @Sendable (Data) -> Void)?
    private(set) var played: [Data] = []
    private(set) var flushCount = 0
    private(set) var stopCount = 0

    func start(onChunk: @escaping @MainActor @Sendable (Data) -> Void) async throws {
        if let startError { throw startError }
        self.onChunk = onChunk
    }

    func play(_ pcm16: Data) { played.append(pcm16) }
    func flushPlayback() { flushCount += 1 }
    func stop() { stopCount += 1 }
}

@Suite struct GeminiLiveWireTests {
    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func content(_ data: Data) throws -> [String: Any] {
        try #require(try object(data)["clientContent"] as? [String: Any])
    }

    private func line(_ id: Int, _ speaker: RoleplayViewModel.Speaker) -> RoleplayViewModel.Line {
        RoleplayViewModel.Line(id: id, speaker: speaker, text: "t\(id)")
    }

    @Test func setupStreamsAudioWithToleranceForPauses() throws {
        let setup = try #require(try object(GeminiLiveClient.setupMessage(system: "sys"))["setup"] as? [String: Any])
        #expect(setup["model"] as? String == "models/gemini-3.8-live")
        let config = try #require(setup["generationConfig"] as? [String: Any])
        #expect(config["responseModalities"] as? [String] == ["AUDIO"])
        #expect(config["speechConfig"] == nil && setup["thinkingConfig"] == nil)
        let input = try #require(setup["inputAudioTranscription"] as? [String: Any])
        #expect(input["languageCodes"] as? [String] == ["ja-JP"])
        #expect(setup["outputAudioTranscription"] != nil)
        let realtime = try #require(setup["realtimeInputConfig"] as? [String: Any])
        let activity = try #require(realtime["automaticActivityDetection"] as? [String: Any])
        #expect(activity["silenceDurationMs"] as? Int == 1200)
        #expect(activity["endOfSpeechSensitivity"] as? String == "END_SENSITIVITY_LOW")
    }

    @Test func audioMessageCarriesBase64Pcm16k() throws {
        let realtime = try #require(try object(GeminiLiveClient.audioMessage(Data([0, 1])))["realtimeInput"] as? [String: Any])
        let audio = try #require(realtime["audio"] as? [String: Any])
        #expect(audio["data"] as? String == "AAE=" && audio["mimeType"] as? String == "audio/pcm;rate=16000")
    }

    @Test func seedWaitsForTheLearnerOnlyWhenThePartnerSpokeLast() throws {
        func roles(_ history: [RoleplayViewModel.Line]) throws -> ([String?], Bool?) {
            let body = try content(GeminiLiveClient.seedMessage(history: history))
            return ((body["turns"] as? [[String: Any]] ?? []).map { $0["role"] as? String }, body["turnComplete"] as? Bool)
        }
        let empty = try roles([])
        #expect(empty.0 == ["user"] && empty.1 == true)
        let partnerLast = try roles([line(0, .partner)])
        #expect(partnerLast.0 == ["user", "model"] && partnerLast.1 == false)
        let learnerLast = try roles([line(0, .partner), line(1, .user)])
        #expect(learnerLast.0 == ["user", "model", "user"] && learnerLast.1 == true)
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

    @Test func parseReportsInterruptionAndLearnerTranscript() {
        #expect(GeminiLiveClient.parse(Data(#"{"serverContent":{"interrupted":true}}"#.utf8)) == [.interrupted])
        let frame = #"{"serverContent":{"inputTranscription":{"text":"もしもし"}}}"#
        #expect(GeminiLiveClient.parse(Data(frame.utf8)) == [.inputTranscript("もしもし")])
    }
}

@MainActor
@Suite struct LiveRoleplayTests {
    private let scenario = RoleplayScenario.bundled.first { $0.id == "phone-company" }!
    private let reviewJSON = #"{"acceptable":true,"corrected":"c","explanation":"e"}"#

    private func make(
        _ partner: FakeLivePartner? = nil, review: FakeLanguageModelClient? = nil, speech: SpySpeech? = nil
    ) -> (RoleplayViewModel, FakeAudioIO) {
        let audio = FakeAudioIO()
        let reviewer = KaiwaAIService(client: review ?? FakeLanguageModelClient(json: reviewJSON))
        let vm = RoleplayViewModel(
            scenario: scenario, mode: .live(partner: partner ?? FakeLivePartner(), reviewer: reviewer, audio: audio),
            speech: speech
        )
        return (vm, audio)
    }

    private func handle(_ vm: RoleplayViewModel, _ events: [LiveEvent]) {
        for event in events { vm.handleLive(event) }
    }

    @Test func openingStreamsAudioAndTranscriptWithoutTTS() async {
        let speech = SpySpeech()
        let partner = FakeLivePartner(
            opening: [.transcript("はい、ABC商事です"), .audio(Data([1, 2])), .turnComplete]
        )
        let (vm, audio) = make(partner, speech: speech)
        await vm.start()
        let session = vm.liveSession
        partner.endSession()
        await session?.value
        #expect(vm.lines.map(\.text) == ["はい、ABC商事です"] && vm.isLiveMode && vm.isFreeMode)
        #expect(audio.played == [Data([1, 2])] && speech.spoken.isEmpty)
        #expect(partner.connectHistoryCounts == [0])
        #expect(vm.errorMessage == "The live session ended." && vm.canRetry)
    }

    @Test func microphoneChunksReachThePartner() async {
        let partner = FakeLivePartner()
        let (vm, audio) = make(partner)
        await vm.start()
        audio.onChunk?(Data([9]))
        #expect(partner.sentAudio == [Data([9])] && vm.isMicrophoneOn && vm.liveStatus == .listening)
    }

    @Test func spokenTurnBecomesReviewedLines() async {
        let (vm, _) = make()
        await vm.start()
        handle(vm, [
            .inputTranscript("リンと"), .inputTranscript("申します"),
            .transcript("少々"), .transcript("お待ちください"), .turnComplete,
        ])
        await vm.pendingReview?.value
        #expect(vm.lines.map(\.text) == ["リンと申します", "少々お待ちください"])
        #expect(vm.lines[0].verdict == .reviewed(acceptable: true, corrected: "c", explanation: "e"))
        #expect(vm.liveUserDraft.isEmpty && vm.livePartnerDraft.isEmpty && vm.liveStatus == .listening)
    }

    @Test func pauseDoesNotSplitTheLearnerSentence() async {
        let (vm, _) = make()
        await vm.start()
        handle(vm, [.inputTranscript("リンと"), .turnComplete])
        #expect(vm.lines.isEmpty && vm.liveUserDraft == "リンと")
        handle(vm, [.inputTranscript("申します"), .transcript("はい"), .turnComplete])
        #expect(vm.lines.filter { $0.speaker == .user }.map(\.text) == ["リンと申します"])
    }

    @Test func bargeInFlushesAudioAndKeepsTheSpokenPart() async {
        let (vm, audio) = make()
        await vm.start()
        handle(vm, [.transcript("少々お待"), .audio(Data([1])), .interrupted])
        #expect(audio.flushCount == 1 && vm.liveStatus == .listening)
        #expect(vm.lines.last?.speaker == .partner && vm.lines.last?.text == "少々お待")
        handle(vm, [.turnComplete])
        #expect(vm.lines.count == 1)
    }

    @Test func typedLineIsSentAndReviewed() async {
        let partner = FakeLivePartner()
        let (vm, _) = make(partner)
        await vm.start()
        await vm.submit("もしもし")
        #expect(partner.sentTexts == ["もしもし"] && vm.lines.last?.speaker == .user)
    }

    @Test func sessionErrorAllowsRetryFromHistory() async {
        let partner = FakeLivePartner()
        let (vm, audio) = make(partner)
        await vm.start()
        handle(vm, [.transcript("はい"), .turnComplete])
        let session = vm.liveSession
        let stops = audio.stopCount
        partner.endSession(throwing: JudgeFailure())
        await session?.value
        #expect(vm.errorMessage == "boom" && vm.canRetry && !vm.isMicrophoneOn && audio.stopCount == stops + 1)
        await vm.retryLast()
        #expect(partner.connectHistoryCounts == [0, 1] && vm.errorMessage == nil && !vm.canRetry)
    }

    @Test func connectFailureAllowsRetry() async {
        let partner = FakeLivePartner()
        partner.failConnect = true
        let (vm, _) = make(partner)
        await vm.start()
        #expect(vm.errorMessage == "boom" && vm.canRetry && vm.liveStatus == .idle)
    }

    @Test func deniedMicrophoneKeepsTypingAvailable() async {
        let partner = FakeLivePartner()
        let (vm, audio) = make(partner)
        audio.startError = LiveAudioError.microphoneDenied
        await vm.start()
        #expect(vm.errorMessage == LiveAudioError.microphoneDenied.localizedDescription && !vm.isMicrophoneOn)
        await vm.submit("もしもし")
        #expect(partner.sentTexts == ["もしもし"])
    }

    @Test func reviewFailureNeitherBlocksNorRetries() async {
        let review = FakeLanguageModelClient([.failure(JudgeFailure())])
        let (vm, _) = make(review: review)
        await vm.start()
        handle(vm, [.inputTranscript("もしもし"), .transcript("はい"), .turnComplete])
        await vm.pendingReview?.value
        #expect(vm.lines[0].verdict == nil && !vm.canRetry && vm.errorMessage == nil && vm.lines.count == 2)
    }

    @Test func stopsAfterEightLearnerLinesAndClosesTheSession() async {
        let partner = FakeLivePartner()
        let (vm, _) = make(partner)
        await vm.start()
        let closesBefore = partner.closeCount
        for turn in 1...8 {
            await vm.submit("発話\(turn)")
            handle(vm, [.transcript("次"), .turnComplete])
        }
        #expect(vm.isFinished && vm.userTurnCount == 8 && partner.closeCount == closesBefore + 1)
    }

    @Test func endClosesTheSessionAndSilencesAudio() async {
        let partner = FakeLivePartner()
        let (vm, audio) = make(partner)
        await vm.start()
        let session = vm.liveSession
        let stops = audio.stopCount
        let closes = partner.closeCount
        vm.end()
        await session?.value
        #expect(audio.stopCount == stops + 1 && partner.closeCount == closes + 1)
        #expect(vm.liveStatus == .idle && vm.errorMessage == nil)
    }

    @Test func hangUpFinishesTheCall() async {
        let (vm, _) = make()
        await vm.start()
        vm.hangUp()
        #expect(vm.isFinished && vm.liveStatus == .idle && vm.liveSession == nil)
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
            makeGeminiLive: { _ in FakeLivePartner() }
        )
    }

    @Test func liveNeedsGeminiGeneratedContentAndKey() {
        #expect(resolver(engine: .gemini, content: .generated).liveRoleplayPartner() != nil)
        #expect(resolver(engine: .gemini, content: .bundled).liveRoleplayPartner() == nil)
        #expect(resolver(engine: .appleIntelligence, content: .generated).liveRoleplayPartner() == nil)
        #expect(resolver(engine: .gemini, content: .generated, key: "  ").liveRoleplayPartner() == nil)
    }
}
