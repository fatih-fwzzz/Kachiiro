import Foundation
import Testing
@testable import KachiiroCore

/// Produces `available` distinct questions for one drill.
struct StubFactory: QuestionFactory {
    let drill: DrillKind
    let available: Int

    func makeQuestions(count: Int, scope: StudyScope, seed: SeedData, rng: inout some RandomNumberGenerator) -> [QuizQuestion] {
        (0..<min(count, available)).map { question($0) }
    }

    func question(for key: ItemKey, seed: SeedData) -> QuizQuestion? { nil }

    private func question(_ n: Int) -> QuizQuestion {
        QuizQuestion(
            id: ItemKey("stub-\(drill.rawValue):\(n)"), drill: drill, promptTitle: "t", promptBody: "b",
            choices: ["right", "w1", "w2", "w3"], correctChoice: "right", acceptedAnswers: ["right"]
        )
    }
}

final class Clock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_700_000_000)
    func advance(_ s: TimeInterval) { date = date.addingTimeInterval(s) }
}

@MainActor
@Suite struct MockExamTests {
    let seed = TestSeed.shared

    func makeVM(
        scope: StudyScope = .all, factories: [any QuestionFactory] = QuestionFactoryRegistry.all,
        repo: InMemoryProgressRepository? = nil, clock: Clock = Clock(), seedData: SeedData? = nil
    ) -> MockExamViewModel {
        let settings = InMemorySettingsStore()
        settings.scope = scope
        return MockExamViewModel(
            seed: seedData ?? seed, settings: settings, repository: repo ?? InMemoryProgressRepository(), factories: factories,
            now: { clock.date }, randomSeed: 42
        )
    }

    static func stubs(_ overrides: [DrillKind: Int] = [:], default available: Int = 40) -> [any QuestionFactory] {
        DrillKind.allCases.map { StubFactory(drill: $0, available: overrides[$0] ?? available) }
    }

    @Test func allocationHonoredWhenPoolIsLarge() {
        let vm = makeVM()
        vm.start()
        #expect(vm.phase == .running)
        #expect(vm.questions.count == 20)
        var counts: [DrillKind: Int] = [:]
        for q in vm.questions { counts[q.drill, default: 0] += 1 }
        for (drill, n) in MockExamViewModel.allocation { #expect(counts[drill] == n, "\(drill)") }
        let pillars = Dictionary(grouping: vm.questions, by: \.pillar).mapValues(\.count)
        #expect(pillars == [.katsuyou: 6, .goi: 6, .bunpou: 5, .choukai: 3])
        #expect(Set(vm.questions.map(\.id)).count == 20)
        #expect(vm.note == nil)
    }

    @Test func pillarGapIsFilledFromOtherDrillsOfThePillar() {
        // verbForms has nothing; inflectionMatrix covers its three slots too.
        let vm = makeVM(factories: Self.stubs([.verbForms: 0]))
        vm.start()
        #expect(vm.questions.count == 20)
        #expect(vm.questions.filter { $0.pillar == .katsuyou }.count == 6)
        #expect(vm.questions.filter { $0.drill == .inflectionMatrix }.count == 6)
        #expect(vm.note == nil)
    }

    @Test func shortfallIsRedistributedProportionally() {
        // Bunpou can only deliver 1 of its 5.
        let vm = makeVM(factories: Self.stubs([.patternRecognition: 0, .registerShift: 1]))
        vm.start()
        #expect(vm.questions.count == 20)
        let pillars = Dictionary(grouping: vm.questions, by: \.pillar).mapValues(\.count)
        #expect(pillars[.bunpou] == 1)
        let donated = (pillars[.katsuyou] ?? 0) + (pillars[.goi] ?? 0) + (pillars[.choukai] ?? 0)
        #expect(donated == 19)
        #expect((pillars[.katsuyou] ?? 0) > 6 && (pillars[.goi] ?? 0) > 6)
        #expect(vm.note?.contains("bunpou") == true)
    }

    @Test func tinyScopeShrinksTheExamAndSaysSo() {
        let vm = makeVM(factories: Self.stubs(default: 1))
        vm.start()
        #expect(vm.questions.count == 9)
        #expect(vm.note?.contains("Only") == true)
    }

    @Test func singleLessonScopeStaysInScope() {
        let scope = StudyScope(levels: [.a21], lessonRange: 3...3)
        let vm = makeVM(scope: scope)
        vm.start()
        #expect(!vm.questions.isEmpty)
        for q in vm.questions {
            switch q.drill.pillar {
            case .katsuyou, .goi, .choukai:
                if let id = q.id.id, q.id.prefix != "kanji", q.id.prefix != "sent", let w = seed.word(id: id) {
                    #expect(w.level == .a21 && w.lesson == 3, "\(q.id.raw)")
                }
            default: break
            }
        }
    }

    @Test func emptyScopeDoesNotStart() {
        let vm = makeVM(scope: StudyScope(levels: [], lessonRange: nil))
        vm.start()
        #expect(vm.phase == .notStarted)
        #expect(vm.note == PracticeViewModel.emptyScopeMessage)
    }

    @Test func timerExpiryFinishesWithUnansweredAsWrong() {
        let clock = Clock()
        let repo = InMemoryProgressRepository()
        let vm = makeVM(factories: Self.stubs(), repo: repo, clock: clock)
        vm.start()
        for _ in 0..<3 {
            vm.answerChoice("right")
            vm.next()
        }
        clock.advance(10 * 60)
        vm.tick()
        #expect(vm.phase == .running)
        #expect(Int(vm.remaining) == 600)
        clock.advance(10 * 60)
        vm.tick()
        #expect(vm.phase == .finished)
        let r = vm.result
        #expect(r?.total == 20 && r?.correct == 3 && r?.unanswered == 17)
        #expect(abs((r?.duration ?? 0) - 1200) < 0.001)
        #expect(repo.attempts.count == 20)
        #expect(repo.attempts.filter { !$0.correct }.count == 17)
    }

    @Test func summaryMathAndPerPillarBreakdown() throws {
        let clock = Clock()
        let vm = makeVM(factories: Self.stubs(), clock: clock)
        vm.start()
        for i in 0..<20 {
            vm.answerChoice(i < 12 ? "right" : "w1")
            clock.advance(10)
            vm.next()
        }
        #expect(vm.phase == .finished)
        let r = try #require(vm.result)
        #expect(r.total == 20 && r.correct == 12 && r.unanswered == 0)
        #expect(r.wrongQuestions.count == 8)
        #expect(r.byPillar.reduce(0) { $0 + $1.total } == 20)
        #expect(r.byPillar.reduce(0) { $0 + $1.correct } == 12)
        #expect(r.byPillar.map(\.pillar) == [.katsuyou, .goi, .bunpou, .choukai])
        #expect(abs(r.duration - 200) < 0.001)
    }

    @Test func wrongItemsBecomeWeakAfterFinishing() {
        let repo = InMemoryProgressRepository()
        let vm = makeVM(factories: Self.stubs(), repo: repo)
        vm.start()
        vm.answerChoice("right"); vm.next()
        vm.answerChoice("w1"); vm.next()
        vm.submit()
        let weak = Set(repo.weakKeys(limit: 100))
        #expect(weak.count == 19)
        #expect(!weak.contains(vm.questions[0].id))
        #expect(weak.contains(vm.questions[1].id) && weak.contains(vm.questions[2].id))
    }

    @Test func typingAnswersAreValidatedAndRecordedOnce() throws {
        let repo = InMemoryProgressRepository()
        let vm = makeVM(repo: repo)
        vm.start()
        vm.setMode(.typing)
        let q = try #require(vm.questions.first { $0.supportedModes.contains(.typing) })
        while vm.currentQuestion?.id != q.id { vm.next() }
        vm.answerText(q.correctChoice)
        vm.submit()
        vm.submit()
        #expect(repo.attempts.count == vm.questions.count)
        #expect(repo.attempts.first { $0.key == q.id }?.correct == true)
        #expect(repo.attempts.first { $0.key == q.id }?.mode == .typing)
    }

    @Test func noGoingBackAndNoFeedbackState() {
        let vm = makeVM(factories: Self.stubs())
        vm.start()
        let first = vm.currentQuestion?.id
        vm.answerChoice("w1")
        vm.next()
        #expect(vm.index == 1 && vm.currentQuestion?.id != first)
        #expect(vm.result == nil)
    }

    @Test func retrySessionCoversWrongAndUnanswered() throws {
        let vm = makeVM(factories: Self.stubs())
        vm.start()
        vm.answerChoice("right")
        vm.submit()
        let retry = try #require(vm.makeRetrySession())
        #expect(retry.total == 19)
    }
}
