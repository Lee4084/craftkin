import Foundation

nonisolated struct LegalConsentStore {
    static let currentVersion = "craftkin-legal-v1"
    private let defaults: UserDefaults
    private let version: String
    private let key: String

    init(defaults: UserDefaults = .standard, version: String = Self.currentVersion) {
        self.defaults = defaults
        self.version = version
        key = "legal.acceptedVersion"
    }

    var hasAccepted: Bool { defaults.string(forKey: key) == version }

    func accept() {
        defaults.set(version, forKey: key)
    }
}
