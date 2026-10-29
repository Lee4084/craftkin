import Combine
import Foundation

@MainActor
final class CaptureCoordinator: ObservableObject {
    @Published var route: CaptureRoute = .entry
    @Published var draft: CaptureDraft
    @Published var validationMessage: String?
    @Published var isRecording = false
    @Published var recordingSeconds: TimeInterval = 0
    @Published var showsPreview = false

    private let store: any CaptureDraftStoring
    private var history: [CaptureRoute] = []
    var onPublished: ((CaptureDraft) throws -> Void)?
    var preferredMaker: String?

    init(store: any CaptureDraftStoring, draft: CaptureDraft? = nil) {
        self.store = store
        self.draft = draft ?? (try? store.load()) ?? .empty
    }

    var hasSavedDraft: Bool {
        draft.sourceDuration > 0 || !draft.title.isEmpty
    }

    var backTitle: String {
        guard let previous = history.last else { return "Capture" }
        switch previous {
        case .entry: return "Capture"
        case .recording: return "Recording"
        case .details: return "Details"
        case .processing: return "Processing"
        case .transcript: return "Transcript"
        case .materials: return "Materials"
        case .steps: return "Steps"
        case .sharing: return "Sharing"
        case .success: return "Done"
        case .recovery: return "Recovery"
        }
    }

    func startRecording() {
        draft = .fresh()
        draft.maker = preferredMaker ?? ""
        recordingSeconds = 0
        isRecording = false
        navigate(to: .recording)
    }

    func importSampleVideo() {
        draft = .fresh()
        draft.setSourceDuration(128)
        navigate(to: .details)
        persist()
    }

    func importSource(filename: String, duration: TimeInterval) {
        guard duration.isFinite, duration > 0, duration <= 600 else {
            validationMessage = "Choose a playable video up to 10 minutes long."
            return
        }
        draft = .fresh()
        draft.sourceMediaFilename = filename
        draft.maker = preferredMaker ?? ""
        draft.setSourceDuration(duration)
        navigate(to: .details)
        persist()
    }

    func toggleRecording() { isRecording.toggle() }

    func advanceRecording(by seconds: TimeInterval) {
        guard isRecording else { return }
        recordingSeconds = min(recordingSeconds + max(seconds, 0), 600)
        if recordingSeconds == 600 { finishRecording(duration: recordingSeconds) }
    }

    func finishRecording(duration: TimeInterval? = nil) {
        isRecording = false
        let draftID = draft.id
        draft = .fresh()
        draft.id = draftID
        draft.setSourceDuration(duration ?? max(recordingSeconds, 8))
        navigate(to: .details)
        persist()
    }

    func saveDraft() {
        draft.lifecycle = .local
        persist()
        returnToEntry()
    }

    @discardableResult
    func createLessonDraft() -> Bool {
        guard draft.metadataErrors.isEmpty else {
            validationMessage = "Add a title, maker and spoken language before creating the lesson."
            return false
        }
        guard draft.sourceDuration > 0, draft.sourceDuration <= 600 else {
            validationMessage = "Choose a video up to 10 minutes long."
            return false
        }
        validationMessage = nil
        draft.lifecycle = .processing
        draft.processingStage = .source
        draft.completedStages = [.source]
        persist()
        navigate(to: .processing)
        return true
    }

    func completeLocalProcessing() {
        let metadata = draft
        if metadata.sourceMediaFilename != nil {
            draft.transcript = [TranscriptSegment(id: UUID().uuidString, start: 0, end: metadata.sourceDuration,
                                                  speaker: metadata.maker, text: "", needsReview: true)]
            draft.ingredients = []
            draft.tools = []
            draft.steps = [LessonDraftStep(id: UUID().uuidString, title: metadata.title,
                                           instruction: "", start: 0, end: metadata.sourceDuration)]
            draft.lifecycle = .needsReview
            persist()
            navigate(to: .transcript)
            return
        }
        var processed = CaptureDraft.sample
        processed.id = metadata.id
        processed.title = metadata.title.isEmpty ? processed.title : metadata.title
        processed.maker = metadata.maker.isEmpty ? processed.maker : metadata.maker
        processed.language = metadata.language.isEmpty ? processed.language : metadata.language
        processed.category = metadata.category
        processed.familyStory = metadata.familyStory
        processed.keepOriginalVoice = metadata.keepOriginalVoice
        let sourceDuration = metadata.sourceDuration
        let sampleDuration = max(processed.sourceDuration, 1)
        let timelineScale = sourceDuration / sampleDuration
        processed.sourceDuration = sourceDuration
        processed.transcript = processed.transcript.map { segment in
            var scaled = segment
            scaled.start *= timelineScale
            scaled.end *= timelineScale
            return scaled
        }
        processed.ingredients = processed.ingredients.map { item in
            var scaled = item
            scaled.sourceTime = item.sourceTime.map { $0 * timelineScale }
            return scaled
        }
        processed.tools = processed.tools.map { item in
            var scaled = item
            scaled.sourceTime = item.sourceTime.map { $0 * timelineScale }
            return scaled
        }
        processed.steps = processed.steps.map { step in
            var scaled = step
            scaled.start *= timelineScale
            scaled.end *= timelineScale
            return scaled
        }
        processed.lifecycle = .needsReview
        draft = processed
        persist()
        navigate(to: .transcript)
    }

    func failTranscriptProcessing() {
        draft.lifecycle = .needsAttention
        draft.processingStage = .transcript
        persist()
        navigate(to: .recovery)
    }

    func retryTranscript() {
        draft.lifecycle = .processing
        draft.processingStage = .transcript
        persist()
        navigate(to: .processing)
    }

    func editTranscriptManually() {
        if draft.transcript.isEmpty {
            draft.transcript = [
                TranscriptSegment(id: "manual-1", start: 0, end: max(draft.sourceDuration, 1), speaker: draft.maker, text: "Tap Edit to add the family member's words.", needsReview: true)
            ]
        }
        draft.lifecycle = .needsReview
        persist()
        navigate(to: .transcript)
    }

    func approveTranscript() {
        guard draft.transcript.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            validationMessage = "Add the maker’s words before approving the transcript."
            return
        }
        draft.transcriptApproved = true
        persist()
        navigate(to: .materials)
    }

    func approveMaterials() {
        draft.materialsApproved = true
        persist()
        navigate(to: .steps)
    }

    @discardableResult
    func approveSteps() -> Bool {
        guard draft.hasValidStepRanges else {
            validationMessage = "Step times must stay inside the video and cannot overlap."
            return false
        }
        draft.stepsApproved = true
        draft.lifecycle = .readyToPublish
        validationMessage = nil
        persist()
        navigate(to: .sharing)
        return true
    }

    func publish() {
        guard draft.transcriptApproved, draft.materialsApproved, draft.stepsApproved else {
            validationMessage = "Review the transcript, materials and steps before publishing."
            return
        }
        guard draft.metadataErrors.isEmpty, draft.hasValidStepRanges else {
            validationMessage = "Check the lesson details and step times before publishing."
            return
        }
        var publishedDraft = draft
        publishedDraft.lifecycle = .published
        do {
            try onPublished?(publishedDraft)
            try store.save(publishedDraft)
        } catch {
            validationMessage = "This lesson could not be saved. Your draft is still available. Please try again."
            return
        }
        draft = publishedDraft
        navigate(to: .success)
    }

    func previewLesson() {
        guard draft.hasValidStepRanges else {
            validationMessage = "Check the step times before previewing this lesson."
            return
        }
        showsPreview = true
    }

    func addStep() {
        guard let last = draft.steps.last else {
            draft.steps = [LessonDraftStep(id: UUID().uuidString, title: "New step", instruction: "", start: 0, end: draft.sourceDuration)]
            return
        }
        let split = (last.start + last.end) / 2
        draft.steps[draft.steps.count - 1].end = split
        draft.steps.append(LessonDraftStep(id: UUID().uuidString, title: "New step", instruction: "", start: split, end: last.end))
        persist()
    }

    func continueDraft() {
        if draft.lifecycle == .needsAttention {
            navigate(to: .recovery)
        } else if draft.transcript.isEmpty {
            navigate(to: .details)
        } else if !draft.transcriptApproved {
            navigate(to: .transcript)
        } else if !draft.materialsApproved {
            navigate(to: .materials)
        } else if !draft.stepsApproved {
            navigate(to: .steps)
        } else {
            navigate(to: .sharing)
        }
    }

    func startAnother() {
        draft = .fresh()
        try? store.delete()
        returnToEntry()
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        route = previous
    }

    func returnToEntry() {
        history.removeAll()
        route = .entry
    }

    private func navigate(to destination: CaptureRoute) {
        guard route != destination else { return }
        history.append(route)
        route = destination
    }

    private func persist() {
        try? store.save(draft)
    }
}
