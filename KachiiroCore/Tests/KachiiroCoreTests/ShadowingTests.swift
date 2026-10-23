import Testing
@testable import KachiiroCore

@Suite struct TextDiffTests {
    @Test func segmentsReconstructBothStrings() {
        let expected = "お待ちしております", actual = "お待ちしています"
        let segs = TextDiff.diff(expected: expected, actual: actual)
        let fromExpected = segs.filter { $0.kind != .extra }.map(\.text).joined()
        let fromActual = segs.filter { $0.kind != .missing }.map(\.text).joined()
        #expect(fromExpected == TypingValidator.normalize(expected))
        #expect(fromActual == TypingValidator.normalize(actual))
    }

    @Test func droppedMoraScoresSevenNinthsAndDoesNotPass() {
        let r = TextDiff.result(expected: "お待ちしております", actual: "お待ちしています")
        #expect(abs(r.score - 7.0 / 9.0) < 1e-9)
        #expect(!r.passed)
        #expect(r.segments.contains { $0.kind == .missing })
    }

    @Test func identicalStringsScoreOneAndPass() {
        let r = TextDiff.result(expected: "かしこまりました", actual: "かしこまりました")
        #expect(r.score == 1 && r.passed)
        #expect(r.segments == [DiffSegment(kind: .match, text: "かしこまりました")])
    }

    @Test func transcriptPunctuationIsIgnored() {
        let r = TextDiff.result(expected: "失礼いたします", actual: "失礼、いたします。")
        #expect(r.score == 1)
    }

    @Test func extraCharactersAreFlaggedButDoNotLowerScore() {
        let r = TextDiff.result(expected: "ありがとう", actual: "ありがとうね")
        #expect(r.score == 1)
        #expect(r.segments.last == DiffSegment(kind: .extra, text: "ね"))
    }

    @Test func emptyExpectedScoresZero() {
        #expect(TextDiff.result(expected: "", actual: "あ").score == 0)
    }
}

@Suite struct ShadowingLineTests {
    @Test func irodoriLinesComeFromPoliteExpressions() {
        let lines = ShadowingLine.irodori(seed: TestSeed.shared)
        #expect(lines.count >= 15)
        #expect(!lines.contains { $0.text == "申し込み" })
        #expect(lines.allSatisfy { !$0.text.contains("～") })
    }

    @Test func bundledLinesPutAuthoredPhrasesFirst() {
        let lines = ShadowingLine.bundledLines(seed: TestSeed.shared)
        #expect(lines.first?.id == "k1")
        #expect(Set(lines.map(\.id)).count == lines.count)
    }
}

@MainActor
@Suite struct ShadowingViewModelTests {
    private func makeModel() -> ShadowingViewModel {
        ShadowingViewModel(lines: [
            ShadowingLine(id: "a", text: "かしこまりました", reading: nil, meaning: "m"),
            ShadowingLine(id: "b", text: "失礼いたします", reading: nil, meaning: "m"),
        ])
    }

    @Test func submitThenNextClearsResult() {
        let vm = makeModel()
        vm.submit("かしこまりました")
        #expect(vm.result?.passed == true)
        vm.next()
        #expect(vm.result == nil)
        #expect(vm.current?.id == "b")
    }

    @Test func navigationClampsAtBothEnds() {
        let vm = makeModel()
        vm.previous()
        #expect(vm.index == 0)
        vm.next(); vm.next()
        #expect(vm.index == 1)
    }

    @Test func blankTranscriptIsIgnored() {
        let vm = makeModel()
        vm.submit("  ")
        #expect(vm.result == nil)
    }
}
