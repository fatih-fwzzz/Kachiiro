import Foundation
import Testing
@testable import KachiiroCore

@MainActor
@Suite struct CanDoTests {
    static let canDos: [CanDo] = {
        let url = TestSeed.repoRoot.appendingPathComponent("Kachiiro/Resources/cando.json")
        // swiftlint:disable:next force_try
        return try! CanDo.load(from: Data(contentsOf: url))
    }()

    static let audioNames = AudioCatalogTests.allNames

    func makeVM(_ repo: InMemoryProgressRepository? = nil) -> CanDoViewModel {
        CanDoViewModel(canDos: Self.canDos, repository: repo ?? InMemoryProgressRepository(), audioFileNames: Self.audioNames)
    }

    @Test func dataShape() {
        let all = Self.canDos
        #expect(all.count == 147)
        #expect(all.filter { $0.book == CanDo.book1 }.map(\.id) == Array(1...69))
        #expect(all.filter { $0.book == CanDo.book2 }.map(\.id) == Array(1...78))
        #expect(Set(all.map(\.storageId)).count == 147)
        #expect(all.filter { $0.book == CanDo.book2 }.map(\.storageId) == Array(1001...1078))
        #expect(all.allSatisfy { !$0.text.isEmpty && !$0.lessonTitle.isEmpty && !$0.topic.isEmpty })
        #expect(all.filter { $0.book == CanDo.book1 }.allSatisfy { $0.level == .a21 })
        #expect(all.filter { $0.book == CanDo.book2 }.allSatisfy { $0.level == .a22 })
    }

    @Test func lessonsAreContiguousWithinEachBook() {
        let vm = makeVM()
        #expect(vm.books == [CanDo.book1, CanDo.book2])
        for book in vm.books {
            let groups = vm.groups(book: book)
            #expect(groups.map(\.lesson) == Array(1...18))
            var expected = 1
            for g in groups {
                #expect(g.items.map(\.id) == Array(expected..<(expected + g.items.count)))
                expected += g.items.count
            }
        }
    }

    @Test func toggleUpdatesProgressAndPersists() throws {
        let repo = InMemoryProgressRepository()
        let vm = makeVM(repo)
        let z = try #require(Self.canDos.first { $0.book == CanDo.book2 && $0.id == 5 })
        let y = try #require(Self.canDos.first { $0.book == CanDo.book1 && $0.id == 5 })
        vm.toggle(z)
        #expect(vm.isDone(z) && !vm.isDone(y))
        #expect(repo.canDoDone() == [1005])
        #expect(vm.progress(book: CanDo.book2).done == 1 && vm.progress(book: CanDo.book2).total == 78)
        #expect(vm.progress(book: CanDo.book1).done == 0)
        #expect(makeVM(repo).isDone(z))
        vm.toggle(z)
        #expect(repo.canDoDone().isEmpty && !vm.isDone(z))
    }

    @Test func tracksOnlyForBookTwo() throws {
        let vm = makeVM()
        let z = try #require(Self.canDos.first { $0.book == CanDo.book2 && $0.lesson == 3 })
        let y = try #require(Self.canDos.first { $0.book == CanDo.book1 && $0.lesson == 3 })
        let tracks = vm.tracks(for: z)
        #expect(!tracks.isEmpty)
        #expect(tracks.allSatisfy { $0.lesson == 3 })
        #expect(vm.tracks(for: y).isEmpty)
    }
}
