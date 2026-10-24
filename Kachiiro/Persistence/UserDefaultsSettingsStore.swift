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

    var kaiwaEngine: KaiwaEngine {
        get { defaults.string(forKey: "kaiwaEngine").flatMap(KaiwaEngine.init(rawValue:)) ?? .rules }
        set { defaults.set(newValue.rawValue, forKey: "kaiwaEngine") }
    }

    var kaiwaContent: KaiwaContentSource {
        get { defaults.string(forKey: "kaiwaContent").flatMap(KaiwaContentSource.init(rawValue:)) ?? .bundled }
        set { defaults.set(newValue.rawValue, forKey: "kaiwaContent") }
    }

    var hasCompletedSetup: Bool {
        get { defaults.bool(forKey: "hasCompletedSetup") }
        set { defaults.set(newValue, forKey: "hasCompletedSetup") }
    }
}
