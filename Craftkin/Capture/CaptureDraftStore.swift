import Foundation

@MainActor
protocol CaptureDraftStoring {
    func load() throws -> CaptureDraft?
    func save(_ draft: CaptureDraft) throws
    func delete() throws
}

@MainActor
final class UserDefaultsCaptureDraftStore: CaptureDraftStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "echoskill.capture.draft") {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> CaptureDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(CaptureDraft.self, from: data)
    }

    func save(_ draft: CaptureDraft) throws {
        defaults.set(try JSONEncoder().encode(draft), forKey: key)
    }

    func delete() throws {
        defaults.removeObject(forKey: key)
    }
}

@MainActor
final class InMemoryCaptureDraftStore: CaptureDraftStoring {
    private var value: CaptureDraft?

    func load() throws -> CaptureDraft? { value }
    func save(_ draft: CaptureDraft) throws { value = draft }
    func delete() throws { value = nil }
}
