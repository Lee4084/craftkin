import Foundation
import Security

struct WebSecureStore {
    func write(_ value: String, account: String) throws {
        let query = base(account)
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw WebIntegrationError.unavailable }
        var record = query
        record[kSecValueData as String] = Data(value.utf8)
        record[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let added = SecItemAdd(record as CFDictionary, nil)
        if added == errSecDuplicateItem {
            guard SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess else {
                throw WebIntegrationError.unavailable
            }
        } else if added != errSecSuccess { throw WebIntegrationError.unavailable }
    }

    func read(_ account: String) throws -> String? {
        var query = base(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { throw WebIntegrationError.unavailable }
        return value
    }

    func installationID() throws -> String {
        let account = IntegrationConstants.Storage.installation
        if let existing = try read(account), !existing.isEmpty { return existing }
        let value = UUID().uuidString
        var query = base(account)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem, let existing = try read(account) { return existing }
        guard status == errSecSuccess else { throw WebIntegrationError.unavailable }
        return value
    }

    private func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: IntegrationConstants.Storage.service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }
}

enum WebEntryMaterialResolver {
    static func resolve(override: String?, cached: String?, persist: (String) throws -> Void) throws -> String? {
        guard let material = override ?? cached else { return nil }
        guard material.utf8.count == 32, material.allSatisfy(\.isASCII) else {
            throw WebIntegrationError.missingEntryMaterial
        }
        if override != nil, material != cached { try persist(material) }
        return material
    }
}
