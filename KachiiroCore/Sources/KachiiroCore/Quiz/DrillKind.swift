/// Raw values double as `-ui-route drill.<raw>` launch arguments.
public enum DrillKind: String, CaseIterable, Sendable {
    case verbForms, inflectionMatrix, vocab, kanji, pitch, patternRecognition, registerShift, dictation, sentenceListening
    case keigo, uchiSoto

    public var pillar: Pillar {
        switch self {
        case .verbForms, .inflectionMatrix: .katsuyou
        case .vocab, .kanji, .pitch: .goi
        case .patternRecognition, .registerShift: .bunpou
        case .dictation, .sentenceListening: .choukai
        case .keigo, .uchiSoto: .kaiwa
        }
    }

    public var title: String {
        switch self {
        case .verbForms: "Verb forms"
        case .inflectionMatrix: "Inflection matrix"
        case .vocab: "Vocabulary"
        case .kanji: "Kanji"
        case .pitch: "Pitch accent"
        case .patternRecognition: "Pattern recognition"
        case .registerShift: "Plain ↔ Polite"
        case .dictation: "Dictation"
        case .sentenceListening: "Sentence listening"
        case .keigo: "Keigo transformer"
        case .uchiSoto: "Uchi / Soto"
        }
    }
}
