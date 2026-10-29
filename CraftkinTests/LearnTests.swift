import Foundation
import Testing
@testable import Craftkin

@MainActor
struct LearningProgressTests {
    @Test("Learning progress round-trips every private checkpoint")
    func persistsProgress() throws {
        let store = InMemoryLearningProgressStore()
        var progress = LearningProgress.fresh(for: LearningLesson.sample)
        progress.completedStepIDs = ["pie-1", "pie-2"]
        progress.checkedMaterialIDs = ["apples", "dough"]
        progress.currentStepIndex = 2
        progress.playbackPosition = 64
        progress.lifecycle = .inProgress

        try store.save(progress)

        #expect(try store.load() == progress)
        let loaded = try store.load()
        let restored = try #require(loaded)
        #expect(restored.isPrivate)
    }

    @Test("Practice validation protects the one-minute and note limits")
    func validatesPractice() {
        var practice = PracticeSubmission.empty
        practice.mediaKind = .video
        practice.mediaDuration = 61
        #expect(practice.validationError == "Choose a video that is 60 seconds or shorter.")

        practice.mediaDuration = 45
        practice.note = String(repeating: "a", count: 501)
        #expect(practice.validationError == "Keep your note to 500 characters or fewer.")

        practice.note = "My first try"
        #expect(practice.validationError == nil)
        #expect(!practice.isSharedWithFamily)
    }
}

@MainActor
struct GroundedLessonAnswererTests {
    @Test("Supported answers cite the approved family lesson")
    func citesApprovedLesson() throws {
        let answer = try #require(
            GroundedLessonAnswerer().answer(
                question: "Why do I leave gaps in the lattice?",
                lesson: .sample
            )
        )

        #expect(answer.text.localizedCaseInsensitiveContains("steam"))
        #expect(answer.sources == ["Grandma’s note · Step 6"])
    }

    @Test("Unsupported answers do not invent family knowledge")
    func refusesUnsupportedKnowledge() throws {
        let answer = try #require(
            GroundedLessonAnswerer().answer(
                question: "What temperature should I roast a turkey?",
                lesson: .sample
            )
        )

        #expect(answer.text == "This lesson doesn't mention that.")
        #expect(answer.sources.isEmpty)
    }
}

@MainActor
struct LearnCoordinatorTests {
    @Test("Materials are remembered but never block starting the lesson")
    func materialsAreOptional() throws {
        let store = InMemoryLearningProgressStore()
        let coordinator = LearnCoordinator(store: store)

        coordinator.startLesson()
        #expect(coordinator.route == .materials)
        coordinator.toggleMaterial("apples")
        #expect(coordinator.progress.checkedMaterialIDs == ["apples"])

        coordinator.beginSteps()
        #expect(coordinator.route == .player)
        #expect(coordinator.progress.lifecycle == .inProgress)
        #expect(try store.load()?.checkedMaterialIDs == ["apples"])
    }

    @Test("Moving between steps never completes them accidentally")
    func navigationDoesNotCompleteSteps() {
        let coordinator = LearnCoordinator(store: InMemoryLearningProgressStore())
        coordinator.startLesson()
        coordinator.beginSteps()

        coordinator.nextStep()
        #expect(coordinator.progress.currentStepIndex == 1)
        #expect(coordinator.progress.completedStepIDs.isEmpty)
        coordinator.previousStep()
        #expect(coordinator.progress.currentStepIndex == 0)
        #expect(coordinator.progress.completedStepIDs.isEmpty)
    }

    @Test("Step completion is idempotent and opens practice after the final step")
    func completesStepsOnce() {
        let coordinator = LearnCoordinator(store: InMemoryLearningProgressStore())
        coordinator.startLesson()
        coordinator.beginSteps()

        for index in LearningLesson.sample.steps.indices {
            coordinator.selectStep(index)
            coordinator.markCurrentStepComplete()
            coordinator.markCurrentStepComplete()
        }

        #expect(coordinator.progress.completedStepIDs.count == LearningLesson.sample.steps.count)
        #expect(coordinator.route == .practiceSubmission)
    }

    @Test("Playback checkpoints stay inside the current approved step")
    func clampsPlayback() {
        let coordinator = LearnCoordinator(store: InMemoryLearningProgressStore())
        coordinator.startLesson()
        coordinator.beginSteps()
        coordinator.selectStep(2)

        coordinator.checkpointPlayback(at: 9_999)
        #expect(coordinator.progress.playbackPosition == LearningLesson.sample.steps[2].end)
        coordinator.replayLastSeconds(5)
        #expect(coordinator.progress.playbackPosition == LearningLesson.sample.steps[2].end - 5)
    }

    @Test("Completion requires every step and creates one durable history event")
    func completesLessonOnce() {
        let store = InMemoryLearningProgressStore()
        let coordinator = LearnCoordinator(store: store)
        coordinator.finishLesson()
        #expect(coordinator.progress.lifecycle != .completed)

        for index in LearningLesson.sample.steps.indices {
            coordinator.selectStep(index)
            coordinator.markCurrentStepComplete()
        }
        coordinator.skipPractice()
        coordinator.finishLesson()
        coordinator.finishLesson()

        #expect(coordinator.route == .completion)
        #expect(coordinator.progress.lifecycle == .completed)
        #expect(coordinator.progress.completionCount == 1)
        #expect(coordinator.progress.completedAt != nil)
    }

    @Test("A private practice can be submitted and shared explicitly")
    func submitsPractice() {
        let coordinator = LearnCoordinator(store: InMemoryLearningProgressStore())
        for index in LearningLesson.sample.steps.indices {
            coordinator.selectStep(index)
            coordinator.markCurrentStepComplete()
        }

        coordinator.choosePracticePhoto()
        coordinator.practice.note = "The lattice is getting easier."
        #expect(coordinator.submitPractice())
        #expect(coordinator.route == .practiceFeedback)
        #expect(!coordinator.progress.practice.isSharedWithFamily)

        coordinator.sharePracticeWithFamily()
        #expect(coordinator.progress.practice.isSharedWithFamily)
    }

    @Test("Learning again creates a fresh pass without erasing history")
    func learnsAgain() {
        let coordinator = LearnCoordinator(store: InMemoryLearningProgressStore())
        for index in LearningLesson.sample.steps.indices {
            coordinator.selectStep(index)
            coordinator.markCurrentStepComplete()
        }
        coordinator.skipPractice()
        coordinator.finishLesson()
        coordinator.learnAgain()

        #expect(coordinator.route == .materials)
        #expect(coordinator.progress.passNumber == 2)
        #expect(coordinator.progress.completionCount == 1)
        #expect(coordinator.progress.completedStepIDs.isEmpty)
    }
}
