import Foundation
import Testing
@testable import Craftkin

@MainActor
struct CaptureDraftTests {
    @Test("Lesson details require a title, maker and language")
    func validatesRequiredMetadata() {
        var draft = CaptureDraft.empty
        #expect(draft.metadataErrors == [.title, .maker, .language])

        draft.title = "Grandma's Dumplings"
        draft.maker = "Mei"
        draft.language = "Mandarin"
        #expect(draft.metadataErrors.isEmpty)
    }

    @Test("Source duration is safely limited to ten minutes")
    func limitsSourceDuration() {
        var draft = CaptureDraft.empty
        draft.setSourceDuration(734)
        #expect(draft.sourceDuration == 600)
        draft.setSourceDuration(-4)
        #expect(draft.sourceDuration == 0)
    }

    @Test("Approved step ranges stay ordered, non-overlapping and inside the source")
    func validatesStepRanges() {
        var draft = CaptureDraft.sample
        draft.sourceDuration = 120
        draft.steps = [
            LessonDraftStep(id: "1", title: "Prepare", instruction: "", start: 0, end: 40),
            LessonDraftStep(id: "2", title: "Fold", instruction: "", start: 35, end: 80)
        ]
        #expect(!draft.hasValidStepRanges)

        draft.steps[1].start = 40
        #expect(draft.hasValidStepRanges)

        draft.steps[1].end = 130
        #expect(!draft.hasValidStepRanges)
    }

    @Test("Draft storage round-trips the complete private draft")
    func persistsDraft() throws {
        let store = InMemoryCaptureDraftStore()
        let original = CaptureDraft.sample
        try store.save(original)
        #expect(try store.load() == original)
        try store.delete()
        #expect(try store.load() == nil)
    }
}

@MainActor
struct CaptureCoordinatorTests {
    @Test("The creator completes the private lesson creation loop")
    func completesCreationFlow() throws {
        let store = InMemoryCaptureDraftStore()
        let coordinator = CaptureCoordinator(store: store)

        coordinator.startRecording()
        #expect(coordinator.route == .recording)
        coordinator.finishRecording(duration: 94)
        #expect(coordinator.route == .details)

        coordinator.draft.title = "Grandma's Dumplings"
        coordinator.draft.maker = "Grandma Mei"
        coordinator.draft.language = "Mandarin"
        #expect(coordinator.createLessonDraft())
        #expect(coordinator.route == .processing)
        #expect(try store.load()?.lifecycle == .processing)

        coordinator.completeLocalProcessing()
        #expect(coordinator.route == .transcript)
        #expect(!coordinator.draft.transcript.isEmpty)
        #expect(coordinator.draft.sourceDuration == 94)

        coordinator.approveTranscript()
        #expect(coordinator.route == .materials)
        coordinator.approveMaterials()
        #expect(coordinator.route == .steps)
        #expect(coordinator.approveSteps())
        #expect(coordinator.route == .sharing)
        coordinator.publish()
        #expect(coordinator.route == .success)
        #expect(coordinator.draft.lifecycle == .published)
    }

    @Test("Only the failed transcript stage is retried or edited manually")
    func recoversTranscriptFailure() {
        let coordinator = CaptureCoordinator(store: InMemoryCaptureDraftStore(), draft: .sample)
        coordinator.failTranscriptProcessing()
        #expect(coordinator.route == .recovery)
        #expect(coordinator.draft.lifecycle == .needsAttention)

        coordinator.retryTranscript()
        #expect(coordinator.route == .processing)
        #expect(coordinator.draft.processingStage == .transcript)

        coordinator.failTranscriptProcessing()
        coordinator.editTranscriptManually()
        #expect(coordinator.route == .transcript)
        #expect(!coordinator.draft.transcript.isEmpty)
    }

    @Test("Continue draft resumes the first incomplete review stage")
    func resumesFirstIncompleteStage() {
        var draft = CaptureDraft.sample
        draft.transcriptApproved = true
        draft.materialsApproved = true
        let coordinator = CaptureCoordinator(store: InMemoryCaptureDraftStore(), draft: draft)

        coordinator.continueDraft()
        #expect(coordinator.route == .steps)
    }
}
