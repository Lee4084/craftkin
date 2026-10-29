import Foundation

protocol LearningProgressStoring {
    func load() throws -> LearningProgress?
    func load(for lessonID: String) throws -> LearningProgress?
    func loadAll() throws -> [LearningProgress]
    func save(_ progress: LearningProgress) throws
    func delete() throws
}

final class InMemoryLearningProgressStore: LearningProgressStoring {
    private var records: [String: LearningProgress] = [:]

    func load() throws -> LearningProgress? { try loadAll().first }
    func load(for lessonID: String) throws -> LearningProgress? { records[lessonID] }
    func loadAll() throws -> [LearningProgress] { records.values.sorted { $0.updatedAt > $1.updatedAt } }
    func save(_ progress: LearningProgress) throws { records[progress.lessonID] = progress }
    func delete() throws { records = [:] }
}

final class UserDefaultsLearningProgressStore: LearningProgressStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "echoskill.learning.apple-pie") {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> LearningProgress? {
        try loadAll().first
    }

    func load(for lessonID: String) throws -> LearningProgress? {
        try loadAll().first { $0.lessonID == lessonID }
    }

    func loadAll() throws -> [LearningProgress] {
        var records: [LearningProgress] = []
        if let data = defaults.data(forKey: key + ".lessons") {
            records = try JSONDecoder().decode([LearningProgress].self, from: data)
        }
        if let legacyData = defaults.data(forKey: key) {
            let legacy = try JSONDecoder().decode(LearningProgress.self, from: legacyData)
            if !records.contains(where: { $0.lessonID == legacy.lessonID }) { records.append(legacy) }
        }
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ progress: LearningProgress) throws {
        var records = try loadAll().filter { $0.lessonID != progress.lessonID }
        records.append(progress)
        defaults.set(try JSONEncoder().encode(records), forKey: key + ".lessons")
        defaults.removeObject(forKey: key)
    }

    func delete() throws {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: key + ".lessons")
    }
}
