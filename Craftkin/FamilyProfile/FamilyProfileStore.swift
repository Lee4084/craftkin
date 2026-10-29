import Foundation

protocol FamilyProfileStateStore {
    func load() throws -> FamilyProfileState?
    func save(_ state: FamilyProfileState) throws
    func delete() throws
}

final class InMemoryFamilyProfileStore: FamilyProfileStateStore {
    private var value: FamilyProfileState?
    init(seed: FamilyProfileState? = nil) { value = seed }
    func load() throws -> FamilyProfileState? { value }
    func save(_ state: FamilyProfileState) throws { value = state }
    func delete() throws { value = nil }
}

final class UserDefaultsFamilyProfileStore: FamilyProfileStateStore {
    private let defaults: UserDefaults
    private let key = "echoskill.familyProfile.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() throws -> FamilyProfileState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(FamilyProfileState.self, from: data)
    }
    func save(_ state: FamilyProfileState) throws {
        defaults.set(try JSONEncoder().encode(state), forKey: key)
    }
    func delete() throws { defaults.removeObject(forKey: key) }
}
