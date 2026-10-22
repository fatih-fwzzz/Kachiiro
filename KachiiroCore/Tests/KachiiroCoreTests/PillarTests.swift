import Testing
@testable import KachiiroCore

@Suite struct PillarTests {
    @Test func offlinePillarCount() {
        #expect(Pillar.allCases.count == 5)
    }
}
