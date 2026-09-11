import Foundation
import Security

public struct OpenRouterKeychain: Sendable {
    private let service: String
    private let account = "api-key"

    public init() { service = "com.emiel.CopyToTranslate.OpenRouter" }
    init(service: String) { self.service = service }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }

    public func load() throws -> String {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { throw DutchProofreadingError.missingKey }
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else {
            throw DutchProofreadingError.keychainUnavailable
        }
        return key
    }

    public func save(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw DutchProofreadingError.missingKey }
        guard key.utf8.allSatisfy({ $0 > 32 && $0 < 127 }) else { throw DutchProofreadingError.invalidKey }
        let attributes = [kSecValueData as String: Data(key.utf8)]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(key.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw DutchProofreadingError.keychainUnavailable
            }
        } else if status != errSecSuccess {
            throw DutchProofreadingError.keychainUnavailable
        }
    }

    public func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DutchProofreadingError.keychainUnavailable
        }
    }
}
