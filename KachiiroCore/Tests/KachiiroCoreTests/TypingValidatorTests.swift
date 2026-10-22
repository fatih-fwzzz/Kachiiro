import Testing
@testable import KachiiroCore

@Suite struct TypingValidatorTests {
    @Test func katakanaFoldsToHiragana() {
        #expect(TypingValidator.normalize("カワナイ") == "かわない")
        #expect(TypingValidator.isCorrect("カワナイ", accepted: ["かわない"]))
    }

    @Test func acceptsAnyAcceptedVariant() {
        #expect(TypingValidator.isCorrect("行って", accepted: ["行って", "いって"]))
        #expect(TypingValidator.isCorrect("いって", accepted: ["行って", "いって"]))
        #expect(!TypingValidator.isCorrect("いた", accepted: ["行って", "いって"]))
    }

    @Test func trimsSpacesAndTrailingPunctuation() {
        #expect(TypingValidator.isCorrect("  いって。", accepted: ["いって"]))
        #expect(TypingValidator.isCorrect("いって\u{3000}", accepted: ["いって"]))
        #expect(TypingValidator.isCorrect("い って！", accepted: ["いって"]))
        #expect(TypingValidator.isCorrect("いって？", accepted: ["いって"]))
    }

    @Test func emptyInputIsNeverCorrect() {
        #expect(!TypingValidator.isCorrect("", accepted: [""]))
        #expect(!TypingValidator.isCorrect("   ", accepted: ["a"]))
    }

    @Test func longVowelMarkIsPreserved() {
        #expect(TypingValidator.normalize("コーヒー") == "こーひー")
        #expect(TypingValidator.normalize("ＡＢＣ") == "abc")
        #expect(TypingValidator.normalize("ﾃｽﾄ") == "てすと")
    }
}
