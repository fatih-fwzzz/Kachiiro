import Foundation
import Testing
@testable import KachiiroCore

@MainActor
final class SpySpeech: SpeechPlaying {
    var hasVoice = true
    var spoken: [(String, Bool)] = []
    func speak(_ text: String, slow: Bool) { spoken.append((text, slow)) }
    func stop() {}
}

@MainActor
@Suite struct QuizSessionViewModelTests {
    static func question(_ n: Int, modes: Set<InputMode> = [.choice, .typing], speech: String? = nil) -> QuizQuestion {
        QuizQuestion(
            id: ItemKey("vocab:\(n):m2w"), drill: .vocab, promptTitle: "t\(n)", promptBody: "b\(n)",
            speech: speech, choices: ["a\(n)", "b\(n)", "c\(n)", "d\(n)"], correctChoice: "a\(n)",
            acceptedAnswers: ["a\(n)", "alt\(n)"], explanation: "e", supportedModes: modes
        )
    }

    func makeVM(mode: InputMode = .choice, speech: SpySpeech? = nil) -> (QuizSessionViewModel, InMemoryProgressRepository) {
        let repo = InMemoryProgressRepository()
        let vm = QuizSessionViewModel(
            questions: [Self.question(1, speech: "音"), Self.question(2), Self.question(3, modes: [.choice])],
            initialMode: mode, repository: repo, speech: speech, now: { Date(timeIntervalSince1970: 1000) }
        )
        return (vm, repo)
    }

    @Test func choiceCorrectAndWrong() {
        let (vm, _) = makeVM()
        vm.submitChoice("a1")
        #expect(vm.result == .correct)
        vm.next()
        vm.submitChoice("b2")
        #expect(vm.result == .wrong(correctAnswer: "a2"))
        #expect(vm.score == 1)
    }

    @Test func typingCorrectAndWrong() {
        let (vm, _) = makeVM(mode: .typing)
        #expect(vm.activeMode == .typing)
        vm.submitText("ALT1")
        #expect(vm.result == .correct)
        vm.next()
        vm.submitText("zzz")
        #expect(vm.result == .wrong(correctAnswer: "a2"))
    }

    @Test func blankTypingIsIgnored() {
        let (vm, repo) = makeVM(mode: .typing)
        vm.submitText("   ")
        #expect(vm.result == nil)
        #expect(repo.attempts.isEmpty)
    }

    @Test func modeSwitchKeepsQuestion() {
        let (vm, _) = makeVM()
        vm.setMode(.typing)
        #expect(vm.mode == .typing)
        #expect(vm.index == 0)
        vm.setMode(.choice)
        #expect(vm.index == 0)
    }

    @Test func typingDisabledOnChoiceOnlyQuestion() {
        let (vm, repo) = makeVM(mode: .typing)
        vm.submitText("a1"); vm.next(); vm.submitText("a2"); vm.next()
        #expect(vm.canType == false)
        #expect(vm.activeMode == .choice)
        vm.setMode(.typing)
        #expect(vm.mode == .typing)
        vm.submitText("a3")
        #expect(vm.result == nil)
        #expect(repo.attempts.count == 2)
    }

    @Test func finishesAfterLastQuestion() {
        let (vm, _) = makeVM()
        for n in 1...3 { vm.submitChoice("a\(n)"); vm.next() }
        #expect(vm.isFinished)
        #expect(vm.score == 3 && vm.total == 3)
        #expect(vm.currentQuestion == nil)
    }

    @Test func recordsOncePerQuestion() {
        let (vm, repo) = makeVM()
        vm.submitChoice("b1")
        vm.submitChoice("a1")
        vm.submitText("a1")
        #expect(repo.attempts.count == 1)
        #expect(repo.attempts.first?.correct == false)
        #expect(vm.answers.count == 1)
    }

    @Test func nextRequiresAnAnswer() {
        let (vm, _) = makeVM()
        vm.next()
        #expect(vm.index == 0)
    }

    @Test func playPromptSpeaksQuestionSpeech() {
        let speech = SpySpeech()
        let (vm, _) = makeVM(speech: speech)
        #expect(vm.hasSpeech)
        vm.playPrompt(slow: true)
        #expect(speech.spoken.count == 1)
        #expect(speech.spoken.first?.0 == "音" && speech.spoken.first?.1 == true)
    }

    @Test func missingVoiceIsReported() {
        let speech = SpySpeech()
        speech.hasVoice = false
        let (vm, _) = makeVM(speech: speech)
        #expect(vm.speechUnavailable)
        #expect(QuizSessionViewModel.missingVoiceMessage.contains("Spoken Content"))
    }

    @Test func bookmarkToggles() {
        let (vm, repo) = makeVM()
        vm.toggleBookmark()
        #expect(vm.isCurrentBookmarked)
        #expect(repo.reviewState(ItemKey("vocab:1:m2w"))?.isBookmarked == true)
        vm.toggleBookmark()
        #expect(!vm.isCurrentBookmarked)
    }

    @Test func retrySessionContainsOnlyWrongQuestions() {
        let (vm, _) = makeVM()
        vm.submitChoice("a1"); vm.next()
        vm.submitChoice("x"); vm.next()
        vm.submitChoice("a3"); vm.next()
        let retry = vm.makeRetrySession()
        #expect(retry?.questions.map(\.id.raw) == ["vocab:2:m2w"])
    }
}
