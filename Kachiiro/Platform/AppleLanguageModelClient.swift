import Foundation
import KachiiroCore

#if canImport(FoundationModels)
import FoundationModels

/// On-device Apple Intelligence behind `LanguageModelClient` (iOS 26+; the framework is weak-linked).
@available(iOS 26.0, *)
nonisolated struct AppleLanguageModelClient: LanguageModelClient {
    nonisolated func generateJSON(system: String, prompt: String, schema: JSONSchema) async throws -> Data {
        let session = LanguageModelSession(model: .default, tools: [], instructions: system)
        let generationSchema = try GenerationSchema(root: Self.map(schema, path: "root"), dependencies: [])
        let response = try await session.respond(to: prompt, schema: generationSchema)
        return Data(response.content.jsonString.utf8)
    }

    /// Dotted property paths keep the schema names unique.
    private nonisolated static func map(_ schema: JSONSchema, path: String) -> DynamicGenerationSchema {
        switch schema {
        case .string(_, let enumValues):
            if let enumValues { return DynamicGenerationSchema(name: path, anyOf: enumValues) }
            return DynamicGenerationSchema(type: String.self)
        case .integer:
            return DynamicGenerationSchema(type: Int.self)
        case .boolean:
            return DynamicGenerationSchema(type: Bool.self)
        case .array(let items, let minItems, let maxItems):
            return DynamicGenerationSchema(
                arrayOf: map(items, path: path + ".item"), minimumElements: minItems, maximumElements: maxItems
            )
        case .object(_, let properties):
            return DynamicGenerationSchema(
                name: path, description: nil,
                properties: properties.map { property in
                    DynamicGenerationSchema.Property(
                        name: property.name, description: property.description,
                        schema: map(property.schema, path: path + "." + property.name)
                    )
                }
            )
        }
    }

    static func availability() -> EngineAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(Locale(identifier: "ja_JP"))
                ? .available : .unavailable("the on-device model doesn't support Japanese")
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .unavailable("this device doesn't support Apple Intelligence")
            case .appleIntelligenceNotEnabled: return .unavailable("turn on Apple Intelligence in Settings")
            case .modelNotReady: return .unavailable("the on-device model is still downloading")
            @unknown default: return .unavailable("Apple Intelligence is unavailable")
            }
        }
    }
}
#endif

/// Availability and client construction that compile on every deployment target.
enum AppleIntelligence {
    @MainActor
    static func availability() -> EngineAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return AppleLanguageModelClient.availability() }
        #endif
        return .unavailable("requires iOS 26")
    }

    @MainActor
    static func makeClient() -> LanguageModelClient? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return AppleLanguageModelClient() }
        #endif
        return nil
    }
}
