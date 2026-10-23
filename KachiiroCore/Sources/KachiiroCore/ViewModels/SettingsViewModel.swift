import Foundation
import Observation

@MainActor
@Observable
public final class SettingsViewModel {
    public static let lessonBounds = 1...18
    public static let goalBounds = 10...200
    public static let goalStep = 10

    public private(set) var scope: StudyScope
    public private(set) var inputMode: InputMode
    public private(set) var examDate: Date?
    public private(set) var dailyGoal: Int
    public private(set) var kaiwaEngine: KaiwaEngine
    public private(set) var kaiwaContent: KaiwaContentSource
    public private(set) var hasGeminiKey: Bool

    private let store: SettingsStore
    private let repository: ProgressRepository
    private let keys: APIKeyStore
    private let aiResolver: KaiwaAIResolver

    public init(store: SettingsStore, repository: ProgressRepository, keys: APIKeyStore, aiResolver: KaiwaAIResolver) {
        self.store = store
        self.repository = repository
        self.keys = keys
        self.aiResolver = aiResolver
        scope = store.scope
        inputMode = store.inputMode
        examDate = store.examDate
        dailyGoal = store.dailyGoal
        kaiwaEngine = store.kaiwaEngine
        kaiwaContent = store.kaiwaContent
        hasGeminiKey = aiResolver.availability(of: .gemini) == .available
    }

    public func setKaiwaEngine(_ engine: KaiwaEngine) {
        kaiwaEngine = engine
        store.kaiwaEngine = engine
    }

    public func setKaiwaContent(_ content: KaiwaContentSource) {
        kaiwaContent = content
        store.kaiwaContent = content
    }

    public func availability(of engine: KaiwaEngine) -> EngineAvailability {
        aiResolver.availability(of: engine)
    }

    /// Generated content needs an AI engine; with offline rules the picker is disabled.
    public var isContentPickerEnabled: Bool { kaiwaEngine != .rules }

    /// Trims the key; a blank key is rejected and nothing is stored.
    @discardableResult
    public func saveGeminiKey(_ raw: String) -> Bool {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        keys.setGeminiKey(key)
        hasGeminiKey = true
        return true
    }

    public func removeGeminiKey() {
        keys.setGeminiKey(nil)
        hasGeminiKey = false
    }

    public func isLevelSelected(_ level: Level) -> Bool { scope.levels.contains(level) }

    /// At least one level always stays selected; the last one cannot be switched off.
    public func setLevel(_ level: Level, selected: Bool) {
        var next = scope
        if selected { next.levels.insert(level) } else if next.levels.count > 1 { next.levels.remove(level) }
        commit(next)
    }

    public var isLessonRangeLimited: Bool { scope.lessonRange != nil }
    public var lessonStart: Int { scope.lessonRange?.lowerBound ?? Self.lessonBounds.lowerBound }
    public var lessonEnd: Int { scope.lessonRange?.upperBound ?? Self.lessonBounds.upperBound }

    public func setLessonRangeLimited(_ limited: Bool) {
        var next = scope
        next.lessonRange = limited ? Self.lessonBounds : nil
        commit(next)
    }

    /// Both ends are clamped to 1…18 and kept ordered (the other end follows when they would cross).
    public func setLessonStart(_ value: Int) {
        guard scope.lessonRange != nil else { return }
        let start = min(max(value, Self.lessonBounds.lowerBound), Self.lessonBounds.upperBound)
        var next = scope
        next.lessonRange = start...max(start, lessonEnd)
        commit(next)
    }

    public func setLessonEnd(_ value: Int) {
        guard scope.lessonRange != nil else { return }
        let end = min(max(value, Self.lessonBounds.lowerBound), Self.lessonBounds.upperBound)
        var next = scope
        next.lessonRange = min(lessonStart, end)...end
        commit(next)
    }

    public func setInputMode(_ mode: InputMode) {
        inputMode = mode
        store.inputMode = mode
    }

    public func setDailyGoal(_ goal: Int) {
        dailyGoal = min(max(goal, Self.goalBounds.lowerBound), Self.goalBounds.upperBound)
        store.dailyGoal = dailyGoal
    }

    public func setExamDate(_ date: Date?) {
        examDate = date
        store.examDate = date
    }

    public func resetProgress() {
        repository.resetAll()
    }

    private func commit(_ next: StudyScope) {
        scope = next
        store.scope = next
    }
}
