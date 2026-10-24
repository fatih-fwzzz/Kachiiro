import Foundation

@MainActor
public final class InMemorySettingsStore: SettingsStore {
    public var scope: StudyScope = .all
    public var inputMode: InputMode = .choice
    public var examDate: Date?
    public var dailyGoal: Int = 30
    public var kaiwaEngine: KaiwaEngine = .automatic
    public var kaiwaContent: KaiwaContentSource = .bundled
    public var hasCompletedSetup = false

    public init() {}
}
