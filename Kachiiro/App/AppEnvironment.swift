import Foundation
import Observation
import KachiiroCore

/// Composition root: owns the long-lived dependencies and hands them to the view tree.
@Observable
final class AppEnvironment {
    let seed: SeedData

    init(seed: SeedData) {
        self.seed = seed
    }

    static func live() -> AppEnvironment {
        guard let url = Bundle.main.url(forResource: "irodori_seed", withExtension: "json") else {
            fatalError("irodori_seed.json missing from the app bundle")
        }
        do {
            return AppEnvironment(seed: try SeedData.load(from: Data(contentsOf: url)))
        } catch {
            fatalError("irodori_seed.json could not be decoded: \(error)")
        }
    }
}
