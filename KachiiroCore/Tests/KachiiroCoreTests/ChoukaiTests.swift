import Foundation
import Testing
@testable import KachiiroCore

@Suite struct AudioCatalogTests {
    static let allNames: [String] = {
        let url = Bundle.module.url(forResource: "audio_names", withExtension: "txt", subdirectory: "Fixtures")!
        // swiftlint:disable:next force_try
        return try! String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
    }()

    @Test func parsesRepresentativeNames() throws {
        let tracks = AudioCatalog.parse(fileNames: [
            "Z_[01-01]_kiku1.mp3", "Z_[03-09]_hanasu1-1.mp3", "Z_[16-14]_kiku1+2.mp3", "Z_[14-06]_kaiwa1.mp3",
            "Z_[01-06]_katachi.mp3", "Z_[01-08]_kotoba1-2.mp3", "junk.mp3", "Z_[1-1]_kiku.mp3",
        ])
        #expect(tracks.count == 6)
        let first = try #require(tracks.first { $0.fileName == "Z_[01-01]_kiku1.mp3" })
        #expect(first.lesson == 1 && first.sequence == 1 && first.kind == .kiku && first.label == "Listen 1")
        let speak = try #require(tracks.first { $0.fileName == "Z_[03-09]_hanasu1-1.mp3" })
        #expect(speak.kind == .hanasu && speak.label == "Speak 1-1" && speak.sequence == 9)
        #expect(tracks.first { $0.fileName == "Z_[16-14]_kiku1+2.mp3" }?.label == "Listen 1+2")
        #expect(tracks.first { $0.fileName == "Z_[14-06]_kaiwa1.mp3" }?.label == "Dialogue 1")
        #expect(tracks.first { $0.fileName == "Z_[01-06]_katachi.mp3" }?.label == "Form")
        #expect(tracks.first { $0.fileName == "Z_[01-08]_kotoba1-2.mp3" }?.label == "Vocab 1-2")
    }

    @Test func realCatalogHas338TracksAcrossEighteenLessons() {
        let tracks = AudioCatalog.parse(fileNames: Self.allNames)
        #expect(Self.allNames.count == 338)
        #expect(tracks.count == 338)
        let lessons = AudioCatalog.byLesson(tracks)
        #expect(lessons.map(\.lesson) == Array(1...18))
        for l in lessons {
            #expect(l.tracks.map(\.sequence) == l.tracks.map(\.sequence).sorted())
            #expect(Set(l.tracks.map(\.sequence)).count == l.tracks.count)
        }
    }
}

@MainActor
final class FakeAudioPlayer: AudioPlaying {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 100
    var rate: Float = 1.0
    var loaded: [String] = []
    var failLoad = false
    var playCount = 0

    func load(fileName: String) throws {
        if failLoad { throw CocoaError(.fileNoSuchFile) }
        loaded.append(fileName)
        currentTime = 0
    }
    func play() { isPlaying = true; playCount += 1 }
    func pause() { isPlaying = false }
    func seek(to time: TimeInterval) { currentTime = time }
}

@MainActor
@Suite struct AudioLibraryViewModelTests {
    let names = ["Z_[01-01]_kiku1.mp3", "Z_[01-02]_kiku2.mp3", "Z_[02-01]_kaiwa.mp3"]

    @Test func selectingTrackLoadsTheRightFileAndPlays() throws {
        let player = FakeAudioPlayer()
        let vm = AudioLibraryViewModel(fileNames: names, player: player)
        #expect(vm.lessons.map(\.lesson) == [1, 2])
        let track = try #require(vm.tracks(inLesson: 1).last)
        vm.select(track)
        #expect(player.loaded == ["Z_[01-02]_kiku2.mp3"])
        #expect(player.isPlaying && vm.isPlaying)
        #expect(vm.currentTrack == track)
    }

    @Test func playPauseAndRateForward() throws {
        let player = FakeAudioPlayer()
        let vm = AudioLibraryViewModel(fileNames: names, player: player)
        vm.select(try #require(vm.tracks(inLesson: 2).first))
        vm.togglePlay()
        #expect(!player.isPlaying && !vm.isPlaying)
        vm.togglePlay()
        #expect(player.isPlaying)
        vm.setRate(1.25)
        #expect(player.rate == 1.25 && vm.rate == 1.25)
        vm.select(try #require(vm.tracks(inLesson: 1).first))
        #expect(player.rate == 1.25)
    }

    @Test func skipClampsToTrackBounds() throws {
        let player = FakeAudioPlayer()
        let vm = AudioLibraryViewModel(fileNames: names, player: player)
        vm.select(try #require(vm.tracks(inLesson: 1).first))
        vm.skip(by: -10)
        #expect(player.currentTime == 0)
        vm.skip(by: 10)
        #expect(player.currentTime == 10)
        vm.seek(to: 500)
        #expect(player.currentTime == 100)
    }

    @Test func loadFailureIsReportedAndNothingPlays() throws {
        let player = FakeAudioPlayer()
        player.failLoad = true
        let vm = AudioLibraryViewModel(fileNames: names, player: player)
        vm.select(try #require(vm.tracks(inLesson: 1).first))
        #expect(vm.errorMessage != nil)
        #expect(vm.currentTrack == nil)
        #expect(player.playCount == 0)
        vm.togglePlay()
        #expect(player.playCount == 0)
    }

    @Test func emptyLibraryIsFlagged() {
        let vm = AudioLibraryViewModel(fileNames: ["readme.md"], player: FakeAudioPlayer())
        #expect(vm.isEmpty)
    }
}

@Suite struct ChoukaiFactoryTests {
    let seed = TestSeed.shared

    @Test func dictationSpeaksReadingAndAcceptsBothForms() throws {
        let f = DictationQuestionFactory()
        var rng = SeededRandomNumberGenerator(seed: 1)
        let qs = f.makeQuestions(count: 20, scope: .all, seed: seed, rng: &rng)
        #expect(qs.count == 20)
        FactoryTestSupport.expectWellFormed(qs, f)
        FactoryTestSupport.expectRoundTrip(qs, f, seed: seed)
        for q in qs {
            let w = seed.word(id: q.id.id!)!
            #expect(q.speech == w.reading)
            #expect(q.acceptedAnswers.contains(w.headword) && q.acceptedAnswers.contains(w.reading))
            #expect((2...12).contains(w.reading.count) && !w.reading.contains("～"))
            #expect(q.promptBody == "Listen and answer")
        }
    }

    @Test func dictationDistractorsAreNotHomophones() {
        let f = DictationQuestionFactory()
        var rng = SeededRandomNumberGenerator(seed: 8)
        for q in f.makeQuestions(count: 50, scope: .all, seed: seed, rng: &rng) {
            let w = seed.word(id: q.id.id!)!
            let wrong = Set(q.choices.filter { $0 != q.correctChoice })
            let homophones = Set(seed.words.filter { $0.reading == w.reading && $0.id != w.id }.map(\.headword))
            #expect(wrong.isDisjoint(with: homophones), "\(q.id.raw)")
        }
    }

    @Test func sentenceListeningSpeaksExample() throws {
        let f = SentenceListeningFactory()
        var rng = SeededRandomNumberGenerator(seed: 2)
        let qs = f.makeQuestions(count: 20, scope: .all, seed: seed, rng: &rng)
        #expect(qs.count == 20)
        FactoryTestSupport.expectWellFormed(qs, f)
        FactoryTestSupport.expectRoundTrip(qs, f, seed: seed)
        for q in qs {
            let p = seed.pattern(id: q.id.id!)!
            #expect(q.speech == p.example && q.correctChoice == p.example)
            #expect(q.supportedModes == [.choice])
        }
    }
}
