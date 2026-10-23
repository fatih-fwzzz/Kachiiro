import Foundation

@MainActor
public protocol APIKeyStore: AnyObject {
    func geminiKey() -> String?
    func setGeminiKey(_ key: String?)
}

@MainActor
public final class InMemoryAPIKeyStore: APIKeyStore {
    private var key: String?

    public init(key: String? = nil) { self.key = key }

    public func geminiKey() -> String? { key }
    public func setGeminiKey(_ key: String?) { self.key = key }
}
