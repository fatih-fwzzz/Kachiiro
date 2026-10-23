import Testing
@testable import KachiiroCore

@MainActor
final class FakeRecognizer: SpeechRecognizing {
    var grantsAccess = true
    var startError: Error?
    private(set) var accessRequests = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var sink: (@MainActor (String) -> Void)?

    func requestAccess() async -> Bool {
        accessRequests += 1
        return grantsAccess
    }

    func start(onTranscript: @escaping @MainActor (String) -> Void) throws {
        if let startError { throw startError }
        startCount += 1
        sink = onTranscript
    }

    func stop() { stopCount += 1 }

    func emit(_ text: String) { sink?(text) }
}

@MainActor
@Suite struct VoiceInputModelTests {
    @Test func deniedAccessNeverStartsAndIsNotAskedTwice() async {
        let fake = FakeRecognizer()
        fake.grantsAccess = false
        let voice = VoiceInputModel(recognizer: fake)
        await voice.start()
        await voice.start()
        #expect(voice.state == .denied)
        #expect(fake.startCount == 0)
        #expect(fake.accessRequests == 1)
    }

    @Test func transcriptUpdatesWhileListeningAndStopReturnsLast() async {
        let fake = FakeRecognizer()
        let voice = VoiceInputModel(recognizer: fake)
        await voice.start()
        #expect(voice.state == .listening)
        fake.emit("いらっしゃ")
        fake.emit("いらっしゃいます")
        #expect(voice.transcript == "いらっしゃいます")
        #expect(voice.stop() == "いらっしゃいます")
        #expect(voice.state == .idle)
        #expect(fake.stopCount == 1)
    }

    @Test func startWhileListeningIsIgnoredAndAccessAskedOnce() async {
        let fake = FakeRecognizer()
        let voice = VoiceInputModel(recognizer: fake)
        await voice.start()
        await voice.start()
        #expect(fake.startCount == 1)
        voice.stop()
        await voice.start()
        #expect(fake.startCount == 2)
        #expect(fake.accessRequests == 1)
    }

    @Test func startErrorBecomesFailed() async {
        let fake = FakeRecognizer()
        fake.startError = SpeechRecognitionError.unavailable
        let voice = VoiceInputModel(recognizer: fake)
        await voice.start()
        #expect(voice.state == .failed("Japanese speech recognition is not available right now."))
    }

    @Test func newListeningSessionClearsOldTranscript() async {
        let fake = FakeRecognizer()
        let voice = VoiceInputModel(recognizer: fake)
        await voice.start()
        fake.emit("one")
        voice.cancel()
        #expect(voice.transcript.isEmpty)
        await voice.start()
        #expect(voice.transcript.isEmpty)
    }
}
