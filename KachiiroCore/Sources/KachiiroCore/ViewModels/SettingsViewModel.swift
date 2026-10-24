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

    private let store: SettingsStore
    private let repository: ProgressRepository
    private let aiResolver: KaiwaAIResolver

    public init(store: SettingsStore, repository: ProgressRepository, aiResolver: KaiwaAIResolver) {
        self.store = store
        self.repository = repository
        self.aiResolver = aiResolver
        scope = store.scope
        inputMode = store.inputMode
        examDate = store.examDate
        dailyGoal = store.dailyGoal
        kaiwaEngine = store.kaiwaEngine
        kaiwaContent = store.kaiwaContent
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

    /// The engine actually in use after fallbacks.
    public var activeEngine: KaiwaEngine { aiResolver.activeEngine }

    /// What the learner can pick; Apple Intelligence appears only on devices that have it.
    public var engineChoices: [KaiwaEngine] { aiResolver.engineChoices }

    /// Why the chosen engine isn't the one in use, if it isn't.
    public var engineNotice: String? { aiResolver.notice }

    /// Generated content needs an AI engine; offline, the picker is disabled.
    public var isContentPickerEnabled: Bool { aiResolver.activeEngine != .rules }

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
