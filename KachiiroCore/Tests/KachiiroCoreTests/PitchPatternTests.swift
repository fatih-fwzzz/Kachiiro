import Testing
@testable import KachiiroCore

@Suite struct PitchPatternTests {
    @Test func nakadaka() throws {
        let p = try #require(PitchPattern.parse(pitch: "あいき↓どう", reading: "あいきどう"))
        #expect(p.dropAfter == 3)
        #expect(p.moraCount == 5) // あ・い・き・ど・う
        #expect(p.accentType == .nakadaka)
    }

    @Test func flatMarker() throws {
        let p = try #require(PitchPattern.parse(pitch: "あらう○", reading: "あらう"))
        #expect(p.dropAfter == nil)
        #expect(p.moraCount == 3)
        #expect(p.accentType == .heiban)
    }

    @Test func atamadaka() throws {
        let p = try #require(PitchPattern.parse(pitch: "ア↓イス", reading: "アイス"))
        #expect(p.accentType == .atamadaka)
        #expect(p.dropAfter == 1)
    }

    @Test func odakaAndFirstAlternative() throws {
        let p = try #require(PitchPattern.parse(pitch: "アイスコーヒ↓ー／アイスコ↓ーヒー", reading: "アイスコーヒー"))
        #expect(p.moraCount == 7)
        #expect(p.dropAfter == 6)
        #expect(p.accentType == .nakadaka)
        let odaka = try #require(PitchPattern.parse(pitch: "あたま↓", reading: "あたま"))
        #expect(odaka.accentType == .odaka)
    }

    @Test func smallKanaDoNotCountButSokuonAndLongVowelDo() throws {
        #expect(PitchPattern.morae(of: "きょう") == ["きょ", "う"])
        #expect(PitchPattern.morae(of: "がっこう").count == 4)
        let p = try #require(PitchPattern.parse(pitch: "きょ↓う", reading: "きょう"))
        #expect(p.moraCount == 2)
        #expect(p.dropAfter == 1)
        #expect(PitchPattern.morae(of: "コーヒー").count == 4)
    }

    @Test func moraMismatchReturnsNil() {
        #expect(PitchPattern.parse(pitch: "だんすい○", reading: "だんすいする") == nil)
        #expect(PitchPattern.parse(pitch: "", reading: "あ") == nil)
    }

    @Test func notesAndPunctuationAreIgnored() throws {
        let p = try #require(PitchPattern.parse(pitch: "～せい（にせ↓ん）", reading: "～せい"))
        #expect(p.moraCount == 2)
        #expect(p.accentType == .heiban)
    }

    @Test func highMoraShape() {
        let hei = PitchPattern(moraCount: 4, dropAfter: nil)
        #expect((0..<4).map(hei.isHigh) == [false, true, true, true])
        let naka = PitchPattern(moraCount: 4, dropAfter: 3)
        #expect((0..<4).map(naka.isHigh) == [false, true, true, false])
        let atama = PitchPattern(moraCount: 3, dropAfter: 1)
        #expect((0..<3).map(atama.isHigh) == [true, false, false])
        let oda = PitchPattern(moraCount: 3, dropAfter: 3)
        #expect((0..<3).map(oda.isHigh) == [false, true, true])
    }

    @Test func seedCoverage() {
        let eligible = TestSeed.shared.words.filter {
            PitchPattern.parse(pitch: $0.pitch, reading: $0.reading).map { $0.moraCount >= 2 } ?? false
        }
        #expect(eligible.count > 3000)
    }
}
