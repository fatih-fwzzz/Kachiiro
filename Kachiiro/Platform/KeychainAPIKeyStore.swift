import Foundation
import Security
import KachiiroCore

/// Gemini API key in the Keychain, readable only on this device after the first unlock.
@MainActor
final class KeychainAPIKeyStore: APIKeyStore {
    private let service = "com.muhammadfawwaz.Kachiiro.gemini"
    private let account = "gemini-api-key"

    private var identity: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func geminiKey() -> String? {
        var query = identity
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setGeminiKey(_ key: String?) {
        SecItemDelete(identity as CFDictionary)
        guard let key, let data = key.data(using: .utf8) else { return }
        var attributes = identity
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
