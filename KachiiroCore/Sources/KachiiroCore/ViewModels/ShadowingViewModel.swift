import Foundation
import Observation

@MainActor
@Observable
public final class ShadowingViewModel {
    public static let generatedCount = 10

    public private(set) var lines: [ShadowingLine]
    public private(set) var index = 0
    public private(set) var result: ShadowingResult?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let speech: SpeechPlaying?
    private let generator: KaiwaAIService?

    public init(lines: [ShadowingLine], speech: SpeechPlaying? = nil, generator: KaiwaAIService? = nil) {
        self.lines = lines
        self.speech = speech
        self.generator = generator
    }

    public var current: ShadowingLine? { lines.indices.contains(index) ? lines[index] : nil }
    public var count: Int { lines.count }
    public var hasVoice: Bool { speech?.hasVoice ?? false }

    /// With a generator, replaces the bundled lines by freshly generated ones; on failure keeps them.
    public func load() async {
        guard let generator else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            lines = try await generator.generateShadowingLines(count: Self.generatedCount)
            index = 0
            result = nil
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't generate lines: \(error.localizedDescription). Showing bundled lines."
        }
    }

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
