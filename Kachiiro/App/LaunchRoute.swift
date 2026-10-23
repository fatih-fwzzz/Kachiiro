import Foundation
import KachiiroCore

/// Debug/smoke launch arguments: `-ui-route <route>` and `-ui-mode <choice|typing>`.
/// Routes: dashboard, practice, mock, review, drill.<DrillKind>, audio, cando, settings,
/// kaiwa.roleplay, kaiwa.roleplay.<scenarioId>, kaiwa.shadowing.
enum LaunchRoute: Equatable {
    case dashboard, practice, mock, review, audio, cando, settings
    case drill(DrillKind)
    case roleplay(String?)
    case shadowing

    init?(argument: String) {
        switch argument {
        case "dashboard": self = .dashboard
        case "practice": self = .practice
        case "mock": self = .mock
        case "review": self = .review
        case "audio": self = .audio
        case "cando": self = .cando
        case "settings": self = .settings
        case "kaiwa.roleplay": self = .roleplay(nil)
        case "kaiwa.shadowing": self = .shadowing
        default:
            if argument.hasPrefix("kaiwa.roleplay.") {
                self = .roleplay(String(argument.dropFirst("kaiwa.roleplay.".count)))
                return
            }
            guard argument.hasPrefix("drill."),
                  let drill = DrillKind(rawValue: String(argument.dropFirst("drill.".count))) else { return nil }
            self = .drill(drill)
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let i = arguments.firstIndex(of: flag), arguments.indices.contains(i + 1) else { return nil }
        return arguments[i + 1]
    }

    static func fromProcess(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> LaunchRoute? {
        value(after: "-ui-route", in: arguments).flatMap(LaunchRoute.init(argument:))
    }

    static func inputModeFromProcess(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> InputMode? {
        value(after: "-ui-mode", in: arguments).flatMap(InputMode.init(rawValue:))
    }
}
