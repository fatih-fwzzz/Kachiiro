public struct QuizQuestion: Identifiable, Sendable, Equatable {
    public let id: ItemKey
    public let pillar: Pillar
    public let drill: DrillKind
    public let promptTitle: String
    public let promptBody: String
    public let promptReading: String?
    public let pitch: PitchPattern?
    public let speech: String?
    /// Exactly 4 distinct strings including `correctChoice` when `.choice` is supported, else empty.
    public let choices: [String]
    public let correctChoice: String
    public let acceptedAnswers: [String]
    public let explanation: String
    public let supportedModes: Set<InputMode>
    /// Key phrases (any-of groups) that must all appear in a typed or spoken sentence answer.
    public let keyPhrases: [[String]]
    /// Whether the answer is a spoken sentence (shows the mic button).
    public let isSpeakable: Bool
    /// Situation text handed to an AI judge when the matcher misses.
    public let judgingContext: String?

    public init(
        id: ItemKey, drill: DrillKind, promptTitle: String, promptBody: String,
        promptReading: String? = nil, pitch: PitchPattern? = nil, speech: String? = nil,
        choices: [String], correctChoice: String, acceptedAnswers: [String]? = nil,
        explanation: String = "", supportedModes: Set<InputMode> = [.choice, .typing],
        keyPhrases: [[String]] = [], isSpeakable: Bool = false, judgingContext: String? = nil
    ) {
        self.id = id
        self.pillar = drill.pillar
        self.drill = drill
        self.promptTitle = promptTitle
        self.promptBody = promptBody
        self.promptReading = promptReading
        self.pitch = pitch
        self.speech = speech
        self.choices = supportedModes.contains(.choice) ? choices : []
        self.correctChoice = correctChoice
        var accepted = acceptedAnswers ?? [correctChoice]
        if !accepted.contains(correctChoice) { accepted.insert(correctChoice, at: 0) }
        self.acceptedAnswers = accepted
        self.explanation = explanation
        self.supportedModes = supportedModes
        self.keyPhrases = keyPhrases
        self.isSpeakable = isSpeakable
        self.judgingContext = judgingContext
    }
}
