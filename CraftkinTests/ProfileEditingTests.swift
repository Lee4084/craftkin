import Foundation
import Testing
import UIKit
@testable import Craftkin

@MainActor
struct ProfileEditingTests {
    private func photo() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 600)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 600))
        }
        return try #require(image.pngData())
    }

    @Test("Profile photos are bounded JPEGs and invalid inputs are rejected")
    func validatesPhoto() throws {
        let data = try ProfilePhotoProcessor.jpeg(from: photo())
        let image = try #require(UIImage(data: data)?.cgImage)
        #expect(max(image.width, image.height) <= 512)
        #expect(data.prefix(2) == Data([0xFF, 0xD8]))
        #expect(throws: ProfilePhotoError.self) { try ProfilePhotoProcessor.jpeg(from: Data([1, 2, 3])) }
        #expect(throws: ProfilePhotoError.self) { try ProfilePhotoProcessor.jpeg(from: Data()) }
        #expect(throws: ProfilePhotoError.self) { try ProfilePhotoProcessor.jpeg(from: Data(repeating: 0, count: 20 * 1024 * 1024 + 1)) }
    }

    @Test("Name and avatar save together, survive reopening, and replacing/removing cleans only the old avatar")
    func savesProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let media = LocalMediaStore(directory: directory)
        let store = InMemoryFamilyProfileStore()
        let coordinator = FamilyProfileCoordinator(store: store, mediaStore: media)
        let others = coordinator.state.members.filter { !$0.isCurrentUser }
        #expect(coordinator.updateProfile(name: "  Alex Morgan  ", avatarData: try photo()))
        let first = try #require(coordinator.currentUser?.avatarFilename)
        #expect(media.url(for: first) != nil)
        let restored = FamilyProfileCoordinator(store: store, mediaStore: media)
        #expect(restored.currentUser?.name == "Alex Morgan")
        #expect(restored.currentUser?.avatarFilename == first)
        #expect(restored.updateProfile(name: "Alex Morgan", avatarData: try photo()))
        #expect(media.url(for: first) == nil)
        let second = try #require(restored.currentUser?.avatarFilename)
        #expect(restored.updateProfile(name: "Alex Morgan"))
        #expect(restored.currentUser?.avatarFilename == second)
        #expect(restored.state.members.filter { !$0.isCurrentUser } == others)
        #expect(restored.updateProfile(name: "Alex Morgan", removeAvatar: true))
        #expect(restored.currentUser?.avatarFilename == nil)
        #expect(media.url(for: second) == nil)
    }

    @Test("Invalid names/images and failed saves never change the profile or leave new files")
    func rejectsInvalidOrFailedSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let media = LocalMediaStore(directory: directory)
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore(), mediaStore: media)
        let original = coordinator.state
        #expect(!coordinator.updateProfile(name: " ", avatarData: try photo()))
        #expect(!coordinator.updateProfile(name: String(repeating: "x", count: 81)))
        #expect(!coordinator.updateProfile(name: "Alex", avatarData: Data([1])))
        #expect(coordinator.state == original)
        #expect(try media.usedBytes() == 0)
        let failing = FamilyProfileCoordinator(store: FailingProfileStore(), mediaStore: media)
        #expect(!failing.updateProfile(name: "Alex", avatarData: try photo()))
        #expect(failing.state == original)
        #expect(try media.usedBytes() == 0)
        #expect(failing.profileEditError != nil)
    }

    @Test("Previously saved profiles without an avatar still decode")
    func decodesOldProfile() throws {
        let data = try JSONEncoder().encode(FamilyProfileState.sample)
        #expect(!String(decoding: data, as: UTF8.self).contains("avatarFilename"))
        let restored = try JSONDecoder().decode(FamilyProfileState.self, from: data)
        #expect(restored.members.allSatisfy { $0.avatarFilename == nil })
    }

    @Test("Explicit media exports include only the current profile's owned avatar")
    func exportsAvatar() throws {
        let media = LocalMediaStore()
        let filename = try media.save(ProfilePhotoProcessor.jpeg(from: photo()), extension: "jpg")
        defer { try? media.delete(filename) }
        var profile = FamilyProfileState.sample.members[0]
        profile.avatarFilename = filename
        for includeMedia in [false, true] {
            let data = try LocalExportBuilder().make(profile: profile, familyName: "Example Family", settings: FamilySettings(), lessons: [], progress: [], includeMedia: includeMedia)
            let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let files = try #require(json["mediaFiles"] as? [String: String])
            #expect((files[filename] != nil) == includeMedia)
        }
    }
}

private struct FailingProfileStore: FamilyProfileStateStore {
    func load() throws -> FamilyProfileState? { .sample }
    func save(_ state: FamilyProfileState) throws { throw CocoaError(.fileWriteNoPermission) }
    func delete() throws {}
}
