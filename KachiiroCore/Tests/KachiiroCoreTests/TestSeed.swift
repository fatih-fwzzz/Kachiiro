import Foundation
@testable import KachiiroCore

enum TestSeed {
    static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        return url
    }()

    static let shared: SeedData = {
        let url = repoRoot.appendingPathComponent("Kachiiro/Resources/irodori_seed.json")
        // swiftlint:disable:next force_try
        return try! SeedData.load(from: Data(contentsOf: url))
    }()
}
