import Foundation

public struct JSONSchemaProperty: Sendable, Equatable {
    public let name: String
    public let description: String?
    public let schema: JSONSchema

    public init(_ name: String, _ schema: JSONSchema, description: String? = nil) {
        self.name = name
        self.description = description
        self.schema = schema
    }
}

/// Provider-neutral structured-output schema. Every object property is required.
public indirect enum JSONSchema: Sendable, Equatable {
    case string(description: String? = nil, enumValues: [String]? = nil)
    case integer(description: String? = nil)
    case boolean(description: String? = nil)
    case array(items: JSONSchema, minItems: Int? = nil, maxItems: Int? = nil)
    case object(name: String, properties: [JSONSchemaProperty])

    func jsonObject() -> [String: Any] {
        switch self {
        case .string(let description, let enumValues):
            var out: [String: Any] = ["type": "string"]
            if let description { out["description"] = description }
            if let enumValues { out["enum"] = enumValues }
            return out
        case .integer(let description):
            var out: [String: Any] = ["type": "integer"]
            if let description { out["description"] = description }
            return out
        case .boolean(let description):
            var out: [String: Any] = ["type": "boolean"]
            if let description { out["description"] = description }
            return out
        case .array(let items, let minItems, let maxItems):
            var out: [String: Any] = ["type": "array", "items": items.jsonObject()]
            if let minItems { out["minItems"] = minItems }
            if let maxItems { out["maxItems"] = maxItems }
            return out
        case .object(_, let properties):
            var props: [String: Any] = [:]
            for p in properties {
                var value = p.schema.jsonObject()
                if let d = p.description { value["description"] = d }
                props[p.name] = value
            }
            return ["type": "object", "properties": props, "required": properties.map(\.name)]
        }
    }

    public func jsonObjectData() -> Data {
        (try? JSONSerialization.data(withJSONObject: jsonObject(), options: [.sortedKeys])) ?? Data("{}".utf8)
    }
}
