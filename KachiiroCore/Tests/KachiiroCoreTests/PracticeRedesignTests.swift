import Foundation
import Testing
@testable import KachiiroCore

@MainActor
@Suite struct PracticeRedesignTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test func verbKeysExposeTheirForm() {
        #expect(ItemKey.verb(12, .ta).verbForm == .ta)
        #expect(ItemKey("vocab:1:m2w").verbForm == nil)
        #expect(ItemKey("verb:1:unknown").verbForm == nil)
    }

    @Test func scopeLabels() {
        #expect(StudyScope.all.label == "All books")
        #expect(StudyScope(levels: [.a21], lessonRange: 1...9).label == "初級1 · L1–9")
        #expect(StudyScope(levels: [.a22, .a21], lessonRange: 4...4).label == "初級1 + 初級2 · L4")
        #expect(StudyScope(levels: [.a1, .a22]).label == "入門 + 初級2")
    }

    @Test func practiceRecommendsTheWeakestPillarThenUnpractised() {
        let now = date(2026, 10, 24)
        let repo = InMemoryProgressRepository(calendar: calendar)
        let fresh = PracticeViewModel(seed: TestSeed.shared, settings: InMemorySettingsStore(), repository: repo,
                                      now: { now }, calendar: calendar)
        #expect(fresh.recommendation == .init(drill: .verbForms, reason: .notPractised))
        #expect(fresh.percent(for: .goi) == nil)

        repo.record(ItemKey("vocab:1:m2w"), pillar: .goi, correct: false, mode: .choice, at: now)
        repo.record(ItemKey("vocab:2:m2w"), pillar: .goi, correct: true, mode: .choice, at: now)
        fresh.refresh()
        #expect(fresh.percent(for: .goi) == 50)
        #expect(fresh.recommendation == .init(drill: .vocab, reason: .weakest(percent: 50)))
    }

    @Test func sessionTracksCombosAndDuration() {
        var clock = date(2026, 10, 24)
        let questions = (1...5).map { n in
            QuizQuestion(id: ItemKey("vocab:\(n):m2w"), drill: .vocab, promptTitle: "", promptBody: "\(n)",
                         choices: ["a", "b"], correctChoice: "a")
        }
        let session = QuizSessionViewModel(questions: questions, initialMode: .choice,
                                           repository: InMemoryProgressRepository(), now: { clock })
        for choice in ["a", "a", "b", "a", "a"] {
            session.submitChoice(choice)
            clock += 30
            session.next()
        }
        #expect(session.bestCombo == 2 && session.combo == 2)
        #expect(session.isFinished && session.duration == 150)
    }
}
