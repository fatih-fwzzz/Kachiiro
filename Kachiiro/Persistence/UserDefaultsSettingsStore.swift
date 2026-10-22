import Foundation
import KachiiroCore

@MainActor
final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var scope: StudyScope {
        get {
            defaults.data(forKey: "scope").flatMap { try? JSONDecoder().decode(StudyScope.self, from: $0) } ?? .all
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "scope") }
    }

    var inputMode: InputMode {
        get { defaults.string(forKey: "inputMode").flatMap(InputMode.init(rawValue:)) ?? .choice }
        set { defaults.set(newValue.rawValue, forKey: "inputMode") }
    }

    var examDate: Date? {
        get { defaults.object(forKey: "examDate") as? Date }
        set { defaults.set(newValue, forKey: "examDate") }
    }

    var dailyGoal: Int {
        get { defaults.object(forKey: "dailyGoal") as? Int ?? 30 }
        set { defaults.set(newValue, forKey: "dailyGoal") }
    }
}
