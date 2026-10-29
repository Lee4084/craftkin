import Foundation

struct ArchivedPractice: Codable, Identifiable, Equatable {
    var id: String { "\(lessonID)-\(practice.submittedAt?.timeIntervalSince1970 ?? 0)" }
    let lessonID: String
    let lessonTitle: String
    let practice: PracticeSubmission
}

protocol PracticeArchiveStoring {
    func load() throws -> [ArchivedPractice]
    func upsert(lessonID: String, title: String, practice: PracticeSubmission) throws
    func deleteAll() throws
}

final class UserDefaultsPracticeArchiveStore: PracticeArchiveStoring {
    private let defaults: UserDefaults
    private let key = "echoskill.practices.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() throws -> [ArchivedPractice] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([ArchivedPractice].self, from: data)
    }
    func upsert(lessonID: String, title: String, practice: PracticeSubmission) throws {
        guard practice.submittedAt != nil else { return }
        let entry = ArchivedPractice(lessonID: lessonID, lessonTitle: title, practice: practice)
        var records = try load().filter { $0.id != entry.id }
        records.insert(entry, at: 0)
        defaults.set(try JSONEncoder().encode(records), forKey: key)
    }
    func deleteAll() throws { defaults.removeObject(forKey: key) }
}
