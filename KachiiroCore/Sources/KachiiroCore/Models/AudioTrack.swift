import Foundation

/// One bundled lesson recording, parsed from `Z_[LL-TT]_<kind><suffix>.mp3` (初級2 only).
public struct AudioTrack: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case kiku, hanasu, katachi, kotoba, kaiwa
    }

    public var id: String { fileName }
    public let fileName: String
    public let lesson: Int
    /// Sequential track number inside the lesson.
    public let sequence: Int
    public let kind: Kind
    public let label: String

    public init(fileName: String, lesson: Int, sequence: Int, kind: Kind, label: String) {
        self.fileName = fileName
        self.lesson = lesson
        self.sequence = sequence
        self.kind = kind
        self.label = label
    }
}

public struct LessonAudio: Identifiable, Equatable, Sendable {
    public var id: Int { lesson }
    public let lesson: Int
    public let tracks: [AudioTrack]
}

public enum AudioCatalog {
    private static let pattern = #"^Z_\[(\d{2})-(\d{2})\]_(kiku|hanasu|katachi|kotoba|kaiwa)(.*)\.mp3$"#

    private static func baseLabel(_ kind: AudioTrack.Kind) -> String {
        switch kind {
        case .kiku: "Listen"
        case .hanasu: "Speak"
        case .katachi: "Form"
        case .kotoba: "Vocab"
        case .kaiwa: "Dialogue"
        }
    }

    /// Unmatched names are ignored. Result is ordered by lesson, then sequence.
    public static func parse(fileNames: [String]) -> [AudioTrack] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var tracks: [AudioTrack] = []
        for name in fileNames {
            let range = NSRange(name.startIndex..., in: name)
            guard let m = regex.firstMatch(in: name, range: range), m.numberOfRanges == 5,
                  let lessonR = Range(m.range(at: 1), in: name), let seqR = Range(m.range(at: 2), in: name),
                  let kindR = Range(m.range(at: 3), in: name), let suffixR = Range(m.range(at: 4), in: name),
                  let lesson = Int(name[lessonR]), let seq = Int(name[seqR]),
                  let kind = AudioTrack.Kind(rawValue: String(name[kindR])) else { continue }
            let suffix = String(name[suffixR])
            let label = suffix.isEmpty ? baseLabel(kind) : "\(baseLabel(kind)) \(suffix)"
            tracks.append(AudioTrack(fileName: name, lesson: lesson, sequence: seq, kind: kind, label: label))
        }
        return tracks.sorted { ($0.lesson, $0.sequence) < ($1.lesson, $1.sequence) }
    }

    public static func byLesson(_ tracks: [AudioTrack]) -> [LessonAudio] {
        Dictionary(grouping: tracks, by: \.lesson)
            .map { LessonAudio(lesson: $0.key, tracks: $0.value.sorted { $0.sequence < $1.sequence }) }
            .sorted { $0.lesson < $1.lesson }
    }
}
