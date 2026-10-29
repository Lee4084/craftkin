import Foundation

struct LocalExportBuilder {
    private struct Snapshot: Encodable {
        let exportedAt: Date
        let profile: FamilyMember?
        let familyName: String
        let settings: FamilySettings
        let lessons: [CaptureDraft]
        let learningProgress: [LearningProgress]
        let practices: [ArchivedPractice]
        let mediaFiles: [String: Data]
    }

    func make(profile: FamilyMember?, familyName: String, settings: FamilySettings,
              lessons: [CaptureDraft], progress: [LearningProgress], practices: [ArchivedPractice] = [], includeMedia: Bool) throws -> Data {
        var media: [String: Data] = [:]
        if includeMedia {
            let avatarFiles = profile?.avatarFilename.map { [$0] } ?? []
            let filenames = Set(lessons.compactMap(\.sourceMediaFilename) + progress.compactMap { $0.practice.mediaFilename } + practices.compactMap { $0.practice.mediaFilename } + avatarFiles)
            var total = 0
            for filename in filenames {
                guard let url = LocalMediaStore().url(for: filename) else { continue }
                let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                total += bytes
                guard total <= 25 * 1024 * 1024 else { throw ExportError.mediaTooLarge }
                media[filename] = try Data(contentsOf: url)
            }
        }
        let snapshot = Snapshot(exportedAt: .now, profile: profile, familyName: familyName, settings: settings,
                                lessons: lessons, learningProgress: progress, practices: practices, mediaFiles: media)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    enum ExportError: Error, LocalizedError {
        case mediaTooLarge
        var errorDescription: String? { "Selected media exceeds the 25 MB export limit. Turn off media to export your text and progress." }
    }
}
