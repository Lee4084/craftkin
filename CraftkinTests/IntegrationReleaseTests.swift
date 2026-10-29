import Foundation
import Testing
@testable import Craftkin

@MainActor
struct PublishedLessonIntegrationTests {
    @Test("Published capture drafts round-trip without duplicating the same lesson")
    func publishedDraftsRoundTripAndUpsert() throws {
        let suiteName = "PublishedLessonIntegrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsPublishedLessonStore(defaults: defaults, key: "published")

        var first = CaptureDraft.sample
        first.id = "dumplings"
        try store.upsert(first)

        var revised = first
        revised.title = "Grandma Mei's Dumplings"
        try store.upsert(revised)

        let restored = try store.load()
        #expect(restored.count == 1)
        #expect(restored.first?.title == "Grandma Mei's Dumplings")
    }

    @Test("A reviewed capture draft becomes a complete Library lesson")
    func captureDraftBecomesLibraryLesson() throws {
        var draft = CaptureDraft.sample
        draft.id = "dumplings"
        draft.lifecycle = .published

        let skill = try #require(IntegratedLessonFactory.librarySkill(from: draft))

        #expect(skill.id == "dumplings")
        #expect(skill.title == "Grandma's Dumplings")
        #expect(skill.maker.name == "Grandma Mei")
        #expect(skill.stepCount == 4)
        #expect(skill.materials.contains("2 cups All-purpose flour"))
        #expect(skill.progress == .new)
    }

    @Test("A Library lesson can open as a grounded learning lesson")
    func libraryLessonBecomesLearningLesson() {
        let repository = LocalSampleSkillRepository(state: .populated)
        let skill = repository.skills[1]

        let lesson = IntegratedLessonFactory.learningLesson(from: skill)

        #expect(lesson.id == skill.id)
        #expect(lesson.title == skill.title)
        #expect(lesson.steps.count == skill.steps.count)
        #expect(lesson.knowledge.first?.answer == skill.transcript)
    }

    @Test("Library progress follows real learning progress")
    func learningProgressUpdatesLibrary() {
        let coordinator = LibraryCoordinator(repository: LocalSampleSkillRepository(state: .populated))
        let lesson = IntegratedLessonFactory.learningLesson(from: coordinator.skills[0])
        var progress = LearningProgress.fresh(for: lesson)
        progress.lifecycle = .inProgress
        progress.completedStepIDs = [lesson.steps[0].id]

        coordinator.apply(progress)
        #expect(coordinator.skill(withID: lesson.id)?.progress == .inProgress)
        #expect(coordinator.skill(withID: lesson.id)?.completedSteps == 1)

        progress.lifecycle = .completed
        progress.completedStepIDs = Set(lesson.steps.map(\.id))
        coordinator.apply(progress)
        #expect(coordinator.skill(withID: lesson.id)?.progress == .completed)
    }

    @Test("Restored publications merge with fixtures and can be updated without duplicates")
    func mergePublishedLibrary() throws {
        let store = InMemoryPublishedLessonStore()
        var draft = CaptureDraft.sample
        draft.id = "dumplings"
        draft.lifecycle = .published
        draft.category = ""
        draft.familyStory = ""
        draft.maker = "Alex"
        draft.transcript = []
        try store.upsert(draft)
        var update = draft
        update.title = "Alex's Dumplings"
        try store.upsert(update)
        let repository = IntegratedSkillRepository(base: LocalSampleSkillRepository(state: .empty), publishedDrafts: try store.load())
        #expect(repository.skills.count == 1)
        #expect(repository.makers.first?.relation == "Family")
        #expect(repository.skills.first?.category == "Family Skills")
        let coordinator = LibraryCoordinator(repository: repository)
        coordinator.upsertPublishedDraft(update)
        draft.id = "second"
        coordinator.upsertPublishedDraft(draft)
        coordinator.upsertPublishedDraft(.empty)
        #expect(coordinator.skills.count == 2)
        #expect(coordinator.makers.count == 1)
        coordinator.clearLearningProgress()
        #expect(coordinator.skills.allSatisfy { $0.progress == .new && $0.completedSteps == 0 })
        try store.deleteAll()
        #expect(try store.load().isEmpty)
    }

    @Test("Invalid drafts cannot enter the published library")
    func invalidPublicationRejected() {
        #expect(IntegratedLessonFactory.librarySkill(from: .sample) == nil)
        #expect(IntegratedSkillRepository(base: LocalSampleSkillRepository(state: .populated), publishedDrafts: [.empty]).skills.count == 6)
    }
}

@MainActor
struct ReleaseInputBoundaryTests {
    @Test("Switching lessons preserves separate checkpoints and legacy data")
    func separateLessonProgress() throws {
        let suiteName = "LearningIntegration.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsLearningProgressStore(defaults: defaults, key: "progress")
        let apple = LearningProgress.fresh(for: .sample)
        defaults.set(try JSONEncoder().encode(apple), forKey: "progress")
        let bike = IntegratedLessonFactory.learningLesson(from: LocalSampleSkillRepository(state: .populated).skills[1])
        let coordinator = LearnCoordinator(store: store)
        coordinator.load(bike)
        coordinator.beginSteps()
        coordinator.markCurrentStepComplete()
        coordinator.load(.sample)
        #expect(coordinator.progress.lessonID == "apple-pie")
        #expect(try store.load(for: bike.id)?.completedStepIDs.count == 1)
        #expect(try store.loadAll().count == 2)
        try store.delete()
        #expect(try store.loadAll().isEmpty)
    }

    @Test("Published learning retains the reviewed instructions and source times")
    func publishedLearningUsesReviewedSource() {
        let draft = CaptureDraft.sample
        let lesson = IntegratedLessonFactory.learningLesson(from: draft)
        #expect(lesson.steps[1].instruction == draft.steps[1].instruction)
        #expect(lesson.steps[1].start == draft.steps[1].start)
        #expect(lesson.steps.last?.end == draft.sourceDuration)
    }

    @Test("Repeated publication does not duplicate family activity")
    func familyPublicationIsIdempotent() {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())
        var draft = CaptureDraft.sample
        draft.lifecycle = .published
        let initial = coordinator.state.sharedLessonCount
        coordinator.recordPublishedLesson(draft)
        coordinator.recordPublishedLesson(draft)
        #expect(coordinator.state.sharedLessonCount == initial + 1)
    }

    @Test("Private progress stays out of family activity and explicit sharing is idempotent")
    func integrationPrivacy() {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore(), initialFamilyName: "The Makers")
        #expect(coordinator.state.familyName == "The Makers")
        let initialEvents = coordinator.visibleActivity.count
        let initialPractices = coordinator.state.sharedPracticeCount
        var progress = LearningProgress.fresh(for: .sample)
        progress.lifecycle = .completed
        progress.completionCount = 1
        coordinator.apply(progress)
        #expect(coordinator.visibleActivity.count == initialEvents)
        progress.practice.submittedAt = Date(timeIntervalSince1970: 100)
        progress.practice.isSharedWithFamily = true
        coordinator.apply(progress, lessonTitle: "Apple Pie")
        coordinator.apply(progress, lessonTitle: "Apple Pie")
        #expect(coordinator.state.sharedPracticeCount == initialPractices + 1)
        #expect(coordinator.visibleActivity.first?.summary.contains("Apple Pie") == true)
        coordinator.synchronizeLearningHistory([progress])
        #expect(coordinator.state.completedSkillCount == 1)
        coordinator.synchronizeLearningHistory([])
        #expect(coordinator.state.completedSkillCount == 0)
    }

    @Test("Capture metadata rejects oversized user-controlled text")
    func captureMetadataHasLengthLimits() {
        var draft = CaptureDraft.sample
        draft.title = String(repeating: "T", count: 121)
        draft.maker = String(repeating: "M", count: 81)
        draft.language = String(repeating: "L", count: 61)

        #expect(draft.metadataErrors.contains(.title))
        #expect(draft.metadataErrors.contains(.maker))
        #expect(draft.metadataErrors.contains(.language))
    }

    @Test("Deleting learning history clears the real progress store")
    func deletionClearsLearningStore() throws {
        let learningStore = InMemoryLearningProgressStore()
        try learningStore.save(.fresh(for: .sample))
        let coordinator = FamilyProfileCoordinator(
            store: InMemoryFamilyProfileStore(),
            learningHistoryStore: learningStore
        )

        coordinator.deleteLearningHistory()

        #expect(try learningStore.load() == nil)
        #expect(coordinator.state.completedSkillCount == 0)
    }

    @Test("A failed publication preserves a reviewed draft and shows a retry message")
    func publicationFailureIsRecoverable() {
        enum StorageFailure: Error { case unavailable }
        var draft = CaptureDraft.sample
        draft.transcriptApproved = true
        draft.materialsApproved = true
        draft.stepsApproved = true
        draft.lifecycle = .readyToPublish
        let coordinator = CaptureCoordinator(store: InMemoryCaptureDraftStore(), draft: draft)
        coordinator.onPublished = { _ in throw StorageFailure.unavailable }
        coordinator.publish()
        #expect(coordinator.route != .success)
        #expect(coordinator.draft.lifecycle == .readyToPublish)
        #expect(coordinator.validationMessage != nil)
    }
}
