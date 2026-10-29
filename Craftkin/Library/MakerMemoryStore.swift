import Foundation

protocol MakerMemoryStoring {
    func load() throws -> [String: [String]]
    func save(_ memories: [String: [String]]) throws
}

final class UserDefaultsMakerMemoryStore: MakerMemoryStoring {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() throws -> [String: [String]] {
        guard let data = defaults.data(forKey: "echoskill.makerMemories.v1") else { return [:] }
        return try JSONDecoder().decode([String: [String]].self, from: data)
    }
    func save(_ memories: [String: [String]]) throws {
        defaults.set(try JSONEncoder().encode(memories), forKey: "echoskill.makerMemories.v1")
    }
}
