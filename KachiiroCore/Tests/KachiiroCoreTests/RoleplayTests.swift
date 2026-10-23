import Foundation
import Testing
@testable import KachiiroCore

@MainActor
private final class SpeechSpy: SpeechPlaying {
    var hasVoice = true
    private(set) var spoken: [String] = []
    func speak(_ text: String, slow: Bool) { spoken.append(text) }
    func stop() {}
}

private func fixture() -> RoleplayScenario {
    RoleplayScenario(
        id: "fx", title: "Fixture", titleJa: "試験", setting: "s", userRole: "u", partnerRole: "p", goal: "g",
        start: "a", closing: "bye",
        turns: [
            RoleplayTurn(id: "a", partner: "hello", hint: "greet", replies: [
                RoleplayReply(accepted: ["申します"], keyPhrases: [["申します"]], note: "n1", next: "b"),
                RoleplayReply(accepted: ["参ります"], keyPhrases: [["参ります"]], note: "n2", next: "c"),
            ]),
            RoleplayTurn(id: "b", partner: "turn b", hint: "hb", replies: [
                RoleplayReply(accepted: ["はい"], keyPhrases: [["はい"]], note: "nb", next: nil)
            ]),
            RoleplayTurn(id: "c", partner: "turn c", hint: "hc", replies: [
                RoleplayReply(accepted: ["いいえ"], keyPhrases: [["いいえ"]], note: "nc", next: nil)
            ]),
        ]
    )
}

@MainActor
@Suite struct RoleplayViewModelTests {
    @Test func startSpeaksOpeningLine() async {
        let speech = SpeechSpy()
        let vm = RoleplayViewModel(scenario: fixture(), speech: speech)
        await vm.start()
        #expect(vm.lines.map(\.text) == ["hello"])
        #expect(speech.spoken == ["hello"])
        #expect(vm.currentHint == "greet")
        #expect(vm.modelAnswer == "申します")
    }

    @Test func passingReplyContinuesAtItsNextTurn() async {
        let vm = RoleplayViewModel(scenario: fixture())
        await vm.start()
        await vm.submit("はい、申します。")
        #expect(vm.lines[1].verdict == .passed(note: "n1"))
        #expect(vm.lines.last?.text == "turn b")
        #expect(vm.passedCount == 1 && vm.userTurnCount == 1)
    }

    @Test func secondReplySelectsItsBranch() async {
        let vm = RoleplayViewModel(scenario: fixture())
        await vm.start()
        await vm.submit("参ります")
        #expect(vm.lines.last?.text == "turn c")
    }

    @Test func missContinuesOnFirstReplyWithModelAnswer() async {
        let vm = RoleplayViewModel(scenario: fixture())
        await vm.start()
        await vm.submit("田中さんいる？")
        #expect(vm.lines[1].verdict == .failed(modelAnswer: "申します", note: "n1"))
        #expect(vm.lines.last?.text == "turn b")
        #expect(vm.passedCount == 0)
    }

    @Test func finishingAppendsClosingAndStopsAcceptingInput() async {
        let vm = RoleplayViewModel(scenario: fixture())
        await vm.start()
        await vm.submit("申します")
        await vm.submit("はい")
        #expect(vm.isFinished)
        #expect(vm.lines.last?.text == "bye")
        #expect(vm.currentHint == nil)
        let count = vm.lines.count
        await vm.submit("もう一度")
        #expect(vm.lines.count == count)
        await vm.start()
        #expect(vm.lines.count == 1 && !vm.isFinished)
    }

    @Test func emptyInputIsIgnored() async {
        let vm = RoleplayViewModel(scenario: fixture())
        await vm.start()
        await vm.submit("  　")
        #expect(vm.lines.count == 1)
    }
}

@Suite struct RoleplayContentTests {
    let scenarios = RoleplayScenario.bundled

    @Test func twelveScenariosWithResolvingGraph() {
        #expect(scenarios.count == 12)
        #expect(Set(scenarios.map(\.id)).count == 12)
        for s in scenarios {
            #expect(s.turn(s.start) != nil, "\(s.id) start")
            for t in s.turns {
                for r in t.replies {
                    if let next = r.next { #expect(s.turn(next) != nil, "\(s.id) \(t.id) → \(next)") }
                }
            }
        }
    }

    @Test func everyTurnReachableAndAcyclic() {
        for s in scenarios {
            var reached = Set<String>()
            var cyclic = false
            func visit(_ id: String, _ path: Set<String>) {
                if path.contains(id) { cyclic = true; return }
                reached.insert(id)
                for r in s.turn(id)?.replies ?? [] { if let n = r.next { visit(n, path.union([id])) } }
            }
            visit(s.start, [])
            #expect(!cyclic, "\(s.id) cycle")
            #expect(reached == Set(s.turns.map(\.id)), "\(s.id) unreachable turns")
        }
    }

    @Test func everyReplyAcceptsItsOwnAnswers() {
        for s in scenarios {
            for t in s.turns {
                for r in t.replies {
                    #expect(!r.accepted.isEmpty && !r.keyPhrases.isEmpty, "\(s.id) \(t.id)")
                    for a in r.accepted {
                        #expect(TypingValidator.isCorrect(a, accepted: r.accepted, keyPhrases: r.keyPhrases), "\(s.id) \(t.id) \(a)")
                    }
                }
            }
        }
    }

    @Test func namedScenariosBranch() {
        for id in ["phone-company", "absent-boss-call", "part-time-interview", "decline-invitation"] {
            let s = scenarios.first { $0.id == id }
            #expect(s?.branches == true, "\(id)")
            let branching = s?.turns.first { $0.replies.count > 1 }
            #expect(Set(branching?.replies.map(\.next) ?? []).count == branching?.replies.count, "\(id)")
        }
    }

    @Test func turnCountsAreFiveToEight() {
        for s in scenarios { #expect((5...8).contains(s.turns.count), "\(s.id)") }
    }
}
