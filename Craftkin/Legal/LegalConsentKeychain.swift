import Foundation
import Security

nonisolated struct LegalConsentKeychain {
    func read(_ account: String) throws -> String? {
        var query = base(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { throw LegalIdentityError.unavailable }
        return value
    }

    func createIfAbsent(_ value: String, account: String) throws -> String {
        var query = base(account)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem, let existing = try read(account) { return existing }
        guard status == errSecSuccess else { throw LegalIdentityError.unavailable }
        return value
    }

    private func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "EchoSkill.WebIntegration",
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }
}
