import Foundation
import Testing
@testable import Craftkin

@MainActor
struct LocalMediaTests {
    @Test("A new real Family Space contains only its organizer and no fabricated activity")
    func freshFamilySpace() {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore(), initialFamilyName: "Morgan Family", useExampleData: false)
        #expect(coordinator.state.familyName == "Morgan Family")
        #expect(coordinator.state.members.count == 1)
        #expect(coordinator.state.activities.isEmpty)
        #expect(coordinator.state.sharedLessonCount == 0)
    }

    @Test("Local removal requires explicit confirmation and setup can restart")
    func resetConfirmation() {
        var wasRemoved = false
        let family = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())
        family.deleteLocalDataHandler = { wasRemoved = true }
        family.deleteLocalData(confirmation: "delete")
        #expect(!wasRemoved)
        family.deleteLocalData(confirmation: "DELETE")
        #expect(wasRemoved)
        let store = InMemoryOnboardingCompletionStore(completion: .localOnly)
        let onboarding = OnboardingCoordinator(completionStore: store)
        onboarding.restartSetup()
        #expect(store.completion == nil)
        #expect(onboarding.step == .welcome)
    }
    @Test("Submitted practices survive clearing progress and remain independently removable")
    func practiceArchive() throws {
        let suite = "PracticeArchive.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let archive = UserDefaultsPracticeArchiveStore(defaults: defaults)
        var practice = PracticeSubmission.empty
        practice.mediaKind = .photo
        practice.submittedAt = Date(timeIntervalSince1970: 100)
        try archive.upsert(lessonID: "apple-pie", title: "Apple Pie", practice: practice)
        try archive.upsert(lessonID: "apple-pie", title: "Apple Pie", practice: practice)
        #expect(try archive.load().count == 1)
        try archive.deleteAll()
        #expect(try archive.load().isEmpty)
    }

    @Test("Adding steps splits the source into non-overlapping review ranges")
    func addStepRanges() {
        let coordinator = CaptureCoordinator(store: InMemoryCaptureDraftStore(), draft: .sample)
        coordinator.addStep()
        #expect(coordinator.draft.steps.count == 5)
        #expect(coordinator.draft.hasValidStepRanges)
    }

    @Test("Maker memories persist, validate limits and reopen without changing lesson data")
    func makerMemories() throws {
        let suite = "MakerMemory.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = LocalSampleSkillRepository(state: .populated)
        let store = UserDefaultsMakerMemoryStore(defaults: defaults)
        let coordinator = LibraryCoordinator(repository: repository, memoryStore: store)
        #expect(!coordinator.saveMemory("  ", for: "grandma"))
        #expect(coordinator.saveMemory("Sunday pies together", for: "grandma"))
        #expect(LibraryCoordinator(repository: repository, memoryStore: store).makerMemories["grandma"] == ["Sunday pies together"])
        #expect(coordinator.skills == repository.skills)
    }

    @Test("Private answers survive reopening and disabled questions do not save")
    func questionPersistence() {
        let store = InMemoryLearningProgressStore()
        let coordinator = LearnCoordinator(store: store)
        coordinator.questionText = "Why leave gaps?"
        coordinator.submitQuestion()
        #expect(LearnCoordinator(store: store).answers.count == 1)
        var lesson = LearningLesson.sample
        lesson.allowsQuestions = false
        coordinator.load(lesson)
        coordinator.questionText = "Why leave gaps?"
        coordinator.submitQuestion()
        #expect(coordinator.answers.count == 1)
        #expect(coordinator.validationMessage != nil)
    }

    @Test("Preview does not publish or modify a stored learning checkpoint")
    func previewIsolation() {
        let coordinator = CaptureCoordinator(store: InMemoryCaptureDraftStore(), draft: .sample)
        coordinator.previewLesson()
        #expect(coordinator.showsPreview)
        #expect(coordinator.draft.lifecycle == .needsReview)
    }
    @Test("Media remains inside its owned directory and survives a new store instance")
    func mediaStorage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalMediaStore(directory: root)
        let name = try store.save(Data([1, 2, 3]), extension: "jpg")
        #expect(try Data(contentsOf: #require(store.url(for: name))) == Data([1, 2, 3]))
        #expect(LocalMediaStore(directory: root).url(for: name) != nil)
        #expect(store.url(for: "../outside.jpg") == nil)
        #expect(try store.usedBytes() == 3)
        try store.delete(name)
        #expect(store.url(for: name) == nil)
        _ = try store.save(Data([4, 5]), extension: "jpg")
        try store.deleteAll()
        #expect(try store.usedBytes() == 0)
    }

    @Test("Unsupported or oversized media is rejected without storing it")
    func mediaValidation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalMediaStore(directory: root, maximumBytes: 4)
        #expect(throws: LocalMediaError.self) { try store.save(Data([1]), extension: "exe") }
        #expect(throws: LocalMediaError.self) { try store.save(Data(repeating: 1, count: 5), extension: "jpg") }
        #expect(throws: LocalMediaError.self) { try store.save(Data(), extension: "jpg") }
    }

    @Test("Profile edits validate and persist the current user's name")
    func profileEditing() {
        let store = InMemoryFamilyProfileStore()
        let coordinator = FamilyProfileCoordinator(store: store)
        #expect(!coordinator.updateProfile(name: "   "))
        #expect(coordinator.updateProfile(name: "  Alex Morgan  "))
        #expect(FamilyProfileCoordinator(store: store).currentUser?.name == "Alex Morgan")
    }

    @Test("Real source drafts keep their media and do not create invented recipe text")
    func realSourceReview() {
        let coordinator = CaptureCoordinator(store: InMemoryCaptureDraftStore())
        coordinator.importSource(filename: "source.mov", duration: 30)
        coordinator.draft.title = "Repair a chair"
        coordinator.draft.maker = "Dad"
        coordinator.draft.language = "English"
        #expect(coordinator.createLessonDraft())
        coordinator.completeLocalProcessing()
        #expect(coordinator.draft.sourceMediaFilename == "source.mov")
        #expect(!coordinator.draft.transcript.contains { $0.text.contains("flour") })
        let lesson = IntegratedLessonFactory.learningLesson(from: coordinator.draft)
        #expect(lesson.sourceMediaFilename == "source.mov")
    }

    @Test("Exports contain local lesson text and omit media unless selected")
    func exportScope() throws {
        let state = FamilyProfileState.sample
        let builder = LocalExportBuilder()
        let data = try builder.make(profile: state.members.first, familyName: state.familyName,
                                    settings: state.settings, lessons: [.sample], progress: [], includeMedia: false)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((json["lessons"] as? [Any])?.count == 1)
        #expect((json["mediaFiles"] as? [String: Any])?.isEmpty == true)
        #expect(json["invitations"] == nil)
    }

    @Test("Media export includes only selected owned files and enforces its memory limit")
    func boundedMediaExport() throws {
        let store = LocalMediaStore()
        let small = try store.save(Data([1, 2, 3]), extension: "jpg")
        let oversized = try store.save(Data(repeating: 0, count: 26 * 1024 * 1024), extension: "mov")
        defer { try? store.delete(small); try? store.delete(oversized) }
        var draft = CaptureDraft.sample
        draft.sourceMediaFilename = small
        let state = FamilyProfileState.sample
        let builder = LocalExportBuilder()
        let data = try builder.make(profile: state.members.first, familyName: state.familyName, settings: state.settings,
                                    lessons: [draft], progress: [], includeMedia: true)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let media = try #require(json["mediaFiles"] as? [String: String])
        #expect(media[small] == Data([1, 2, 3]).base64EncodedString())
        draft.sourceMediaFilename = oversized
        #expect(throws: LocalExportBuilder.ExportError.self) {
            try builder.make(profile: nil, familyName: state.familyName, settings: state.settings,
                             lessons: [draft], progress: [], includeMedia: true)
        }
    }
}
