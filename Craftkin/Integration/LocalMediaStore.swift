import Foundation

enum LocalMediaError: Error, LocalizedError {
    case unsupportedType, emptyFile, tooLarge, invalidDuration
    var errorDescription: String? {
        switch self {
        case .unsupportedType: "Choose a supported photo or video."
        case .emptyFile: "This file is empty. Please choose another file."
        case .tooLarge: "Choose a file smaller than 200 MB."
        case .invalidDuration: "Choose a playable video within the allowed time limit."
        }
    }
}

final class LocalMediaStore {
    let directory: URL
    private let maximumBytes: Int
    private let allowedExtensions = Set(["mov", "mp4", "m4v", "jpg", "jpeg", "png", "heic"])

    init(directory: URL? = nil, maximumBytes: Int = 200 * 1024 * 1024) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EchoSkillMedia", isDirectory: true)
        self.maximumBytes = maximumBytes
    }

    func url(for filename: String?) -> URL? {
        guard let filename, !filename.isEmpty, filename == (filename as NSString).lastPathComponent,
              !filename.contains(".."), !filename.contains("\\") else { return nil }
        let url = directory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func save(_ data: Data, extension fileExtension: String) throws -> String {
        try validate(size: data.count, extension: fileExtension)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + "." + fileExtension.lowercased()
        let destination = directory.appendingPathComponent(filename)
        try data.write(to: destination, options: .atomic)
        try protect(destination)
        return filename
    }

    func importFile(_ source: URL) throws -> String {
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        try validate(size: size, extension: source.pathExtension)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + "." + source.pathExtension.lowercased()
        let destination = directory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: source, to: destination)
        try protect(destination)
        return filename
    }

    func delete(_ filename: String) throws {
        guard let ownedURL = url(for: filename) else { return }
        try FileManager.default.removeItem(at: ownedURL)
    }

    func usedBytes() throws -> Int {
        guard FileManager.default.fileExists(atPath: directory.path) else { return 0 }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { total, file in total + ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    func deleteAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: file)
        }
    }

    private func validate(size: Int, extension fileExtension: String) throws {
        guard allowedExtensions.contains(fileExtension.lowercased()) else { throw LocalMediaError.unsupportedType }
        guard size > 0 else { throw LocalMediaError.emptyFile }
        guard size <= maximumBytes else { throw LocalMediaError.tooLarge }
    }

    private func protect(_ url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        #endif
    }
}
