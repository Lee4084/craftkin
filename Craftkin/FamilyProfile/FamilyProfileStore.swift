import Foundation

protocol FamilyProfileStateStore {
    func load() throws -> FamilyProfileState?
    func save(_ state: FamilyProfileState) throws
    func delete() throws
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
