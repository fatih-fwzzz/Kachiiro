import Foundation
import Observation

@MainActor
@Observable
public final class CanDoViewModel {
    public struct LessonGroup: Identifiable, Equatable, Sendable {
        public var id: String { "\(book)-\(lesson)" }
        public let book: String
        public let lesson: Int
        public let title: String
        public let topic: String
        public let items: [CanDo]
    }

    public let canDos: [CanDo]
    public private(set) var done: Set<Int>

    private let repository: ProgressRepository
    private let tracksByLesson: [Int: [AudioTrack]]

    public init(canDos: [CanDo], repository: ProgressRepository, audioFileNames: [String]) {
        self.canDos = canDos
        self.repository = repository
        self.done = repository.canDoDone()
        let tracks = AudioCatalog.parse(fileNames: audioFileNames)
        self.tracksByLesson = Dictionary(grouping: tracks, by: \.lesson)
    }

    public var books: [String] {
        var seen = Set<String>()
        return canDos.map(\.book).filter { seen.insert($0).inserted }
    }

    public func groups(book: String) -> [LessonGroup] {
        Dictionary(grouping: canDos.filter { $0.book == book }, by: \.lesson)
            .map { lesson, items in
                let sorted = items.sorted { $0.id < $1.id }
                return LessonGroup(book: book, lesson: lesson, title: sorted[0].lessonTitle, topic: sorted[0].topic, items: sorted)
            }
            .sorted { $0.lesson < $1.lesson }
    }

    public func isDone(_ canDo: CanDo) -> Bool { done.contains(canDo.storageId) }

    public func toggle(_ canDo: CanDo) {
        let on = !done.contains(canDo.storageId)
        repository.setCanDo(canDo.storageId, done: on)
        if on { done.insert(canDo.storageId) } else { done.remove(canDo.storageId) }
    }

    public func progress(book: String) -> (done: Int, total: Int) {
        let items = canDos.filter { $0.book == book }
        return (items.filter(isDone).count, items.count)
    }

    /// The lesson's bundled recordings; only 初級2 has audio.
    public func tracks(for canDo: CanDo) -> [AudioTrack] {
        canDo.hasAudio ? (tracksByLesson[canDo.lesson] ?? []).sorted { $0.sequence < $1.sequence } : []
    }
}
