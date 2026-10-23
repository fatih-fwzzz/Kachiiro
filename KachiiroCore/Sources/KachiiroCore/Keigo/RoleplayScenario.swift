import Foundation

public struct RoleplayReply: Codable, Sendable, Equatable {
    public let accepted: [String]
    public var keyPhrases: [[String]]
    public let note: String
    /// Id of the next turn; `nil` ends the scenario.
    public let next: String?
}

public struct RoleplayTurn: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let partner: String
    public let hint: String
    public var replies: [RoleplayReply]
}

public struct RoleplayScenario: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let titleJa: String
    public let setting: String
    public let userRole: String
    public let partnerRole: String
    public let goal: String
    public let start: String
    public let closing: String
    public var turns: [RoleplayTurn]

    public func turn(_ id: String) -> RoleplayTurn? { turns.first { $0.id == id } }

    /// Whether any turn offers more than one reply.
    public var branches: Bool { turns.contains { $0.replies.count > 1 } }

    public static func load(from data: Data) throws -> [RoleplayScenario] {
        var scenarios = try JSONDecoder().decode([RoleplayScenario].self, from: data)
        for s in scenarios.indices {
            for t in scenarios[s].turns.indices {
                for r in scenarios[s].turns[t].replies.indices {
                    scenarios[s].turns[t].replies[r].keyPhrases =
                        KeigoEngine.expand(keyPhrases: scenarios[s].turns[t].replies[r].keyPhrases)
                }
            }
        }
        return scenarios
    }

    public static let bundled: [RoleplayScenario] = {
        do {
            guard let url = Bundle.module.url(forResource: "roleplay", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try load(from: Data(contentsOf: url))
        } catch {
            fatalError("roleplay.json missing or invalid: \(error)")
        }
    }()
}
