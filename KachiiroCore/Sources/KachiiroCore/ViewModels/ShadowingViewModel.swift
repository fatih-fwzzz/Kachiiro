import Foundation
import Observation

@MainActor
@Observable
public final class ShadowingViewModel {
    public private(set) var lines: [ShadowingLine]
    public private(set) var index = 0
    public private(set) var result: ShadowingResult?

    private let speech: SpeechPlaying?

    public init(lines: [ShadowingLine], speech: SpeechPlaying? = nil) {
        self.lines = lines
        self.speech = speech
    }

    public var current: ShadowingLine? { lines.indices.contains(index) ? lines[index] : nil }
    public var count: Int { lines.count }
    public var hasVoice: Bool { speech?.hasVoice ?? false }

    public func play(slow: Bool) {
        guard let current else { return }
        speech?.speak(current.text, slow: slow)
    }

    public func submit(_ transcript: String) {
        guard let current,
              !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        result = TextDiff.result(expected: current.text, actual: transcript)
    }

    public func next() { move(to: index + 1) }
    public func previous() { move(to: index - 1) }

    private func move(to newIndex: Int) {
        guard !lines.isEmpty else { return }
        index = min(max(newIndex, 0), lines.count - 1)
        result = nil
    }
}
