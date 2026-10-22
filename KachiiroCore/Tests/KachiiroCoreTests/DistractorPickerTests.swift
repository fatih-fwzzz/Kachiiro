import Testing
@testable import KachiiroCore

@Suite struct DistractorPickerTests {
    let tiers = [["b", "c", "d", "a"], ["e", "f", "b"], ["g"]]

    @Test func seededOutputIsStable() {
        var r1 = SeededRandomNumberGenerator(seed: 42)
        var r2 = SeededRandomNumberGenerator(seed: 42)
        let a = DistractorPicker.pick(correct: "a", accepted: ["a"], tiers: tiers, rng: &r1)
        let b = DistractorPicker.pick(correct: "a", accepted: ["a"], tiers: tiers, rng: &r2)
        #expect(a == b)
        #expect(a?.count == 3)
    }

    @Test func neverContainsAcceptedOrDuplicates() {
        for seed in UInt64(0)..<50 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let picked = DistractorPicker.pick(correct: "a", accepted: ["a", "c"], tiers: tiers, rng: &rng)
            #expect(picked != nil)
            guard let picked else { continue }
            #expect(!picked.contains("a") && !picked.contains("c"))
            #expect(Set(picked).count == picked.count)
        }
    }

    @Test func earlierTiersWinBeforeLaterTiers() {
        var rng = SeededRandomNumberGenerator(seed: 7)
        let picked = DistractorPicker.pick(correct: "x", accepted: [], tiers: [["b", "c", "d"], ["e", "f"]], rng: &rng)
        #expect(Set(picked ?? []) == ["b", "c", "d"])
    }

    @Test func returnsNilWhenShort() {
        var rng = SeededRandomNumberGenerator(seed: 1)
        #expect(DistractorPicker.pick(correct: "a", accepted: ["a"], tiers: [["a", "b"], ["b", "c"]], rng: &rng) == nil)
    }
}
