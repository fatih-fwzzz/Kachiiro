import Foundation

@MainActor
public protocol SettingsStore: AnyObject {
    var scope: StudyScope { get set }
    var inputMode: InputMode { get set }
    var examDate: Date? { get set }
    var dailyGoal: Int { get set }
    var kaiwaEngine: KaiwaEngine { get set }
    var kaiwaContent: KaiwaContentSource { get set }
}
