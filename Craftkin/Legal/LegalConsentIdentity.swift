import Foundation

nonisolated enum LegalIdentityError: Error { case unavailable, invalid }

nonisolated struct LegalConsentIdentityStore {
    static let account = "activity.installation.identifier"
    static func isValid(_ value: String) -> Bool { value.utf8.count == 36 && UUID(uuidString: value) != nil }

    func resolve(migrating candidate: String?, read: () throws -> String? = {
        try LegalConsentKeychain().read(Self.account)
    }, create: (String) throws -> String = {
        try LegalConsentKeychain().createIfAbsent($0, account: Self.account)
    }) throws -> String {
        if let candidate, !Self.isValid(candidate) { throw LegalIdentityError.invalid }
        if let existing = try read() {
            guard Self.isValid(existing) else { throw LegalIdentityError.invalid }
            return existing
        }
        let value = try create(candidate ?? UUID().uuidString.lowercased())
        guard Self.isValid(value) else { throw LegalIdentityError.invalid }
        return value
    }
}
