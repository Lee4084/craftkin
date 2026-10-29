import Combine
import Foundation

@MainActor
final class LearnCoordinator: ObservableObject {
    @Published var route: LearningRoute = .dashboard
    @Published private(set) var progress: LearningProgress
    @Published var practice: PracticeSubmission
    @Published private(set) var answers: [GroundedAnswer] = []
    @Published var questionText = ""
    @Published var validationMessage: String?
    @Published private(set) var playbackSeekToken = 0
    @Published var availableLessons: [LearningLesson] = []

    @Published private(set) var lesson: LearningLesson
    private let store: any LearningProgressStoring
    private let answerer: GroundedLessonAnswerer
    var onProgressChanged: ((LearningProgress) -> Void)?

    init(
        lesson: LearningLesson? = nil,
        store: any LearningProgressStoring,
        answerer: GroundedLessonAnswerer? = nil
    ) {
        let lesson = lesson ?? .sample
        self.lesson = lesson
        self.store = store
        self.answerer = answerer ?? GroundedLessonAnswerer()
        let restored = try? store.load(for: lesson.id)
        let current = restored.flatMap { $0.revisionID == lesson.revisionID ? $0 : nil }
            ?? LearningProgress.fresh(for: lesson)
        progress = current
        practice = current.practice
        answers = current.questionHistory ?? []
    }

    var currentStep: LearningStep {
        lesson.steps[clampedStepIndex]
    }

    var clampedStepIndex: Int {
        min(max(progress.currentStepIndex, 0), max(lesson.steps.count - 1, 0))
    }

    var completedFraction: Double {
        guard !lesson.steps.isEmpty else { return 0 }
        return Double(progress.completedStepIDs.count) / Double(lesson.steps.count)
    }

    var canFinish: Bool {
        progress.completedStepIDs.count == lesson.steps.count
    }

    var isDashboardVisible: Bool {
        route == .dashboard || route == .history
    }

    func startLesson() {
        route = .materials
    }

    func toggleMaterial(_ id: String) {
        if progress.checkedMaterialIDs.contains(id) {
            progress.checkedMaterialIDs.remove(id)
        } else {
            progress.checkedMaterialIDs.insert(id)
        }
        save()
    }

    func beginSteps() {
        progress.lifecycle = .inProgress
        save()
        route = .player
    }

    func resumeLesson() {
        route = progress.lifecycle == .ready ? .materials : .player
    }

    func selectStep(_ index: Int) {
        guard lesson.steps.indices.contains(index) else { return }
        progress.currentStepIndex = index
        progress.playbackPosition = lesson.steps[index].start
        playbackSeekToken += 1
        save()
    }

    func nextStep() {
        selectStep(min(clampedStepIndex + 1, lesson.steps.count - 1))
    }

    func previousStep() {
        selectStep(max(clampedStepIndex - 1, 0))
    }

    func checkpointPlayback(at seconds: TimeInterval) {
        progress.playbackPosition = min(max(seconds, currentStep.start), currentStep.end)
        save()
    }

    func replayLastSeconds(_ seconds: TimeInterval = 5) {
        checkpointPlayback(at: progress.playbackPosition - max(seconds, 0))
        playbackSeekToken += 1
    }

    func markCurrentStepComplete() {
        progress.lifecycle = .inProgress
        progress.completedStepIDs.insert(currentStep.id)
        save()
        if canFinish {
            practice = progress.practice
            route = .practiceSubmission
        } else {
            nextStep()
        }
    }

    func askQuestion() {
        route = .questionAnswer
    }

    func submitQuestion() {
        guard lesson.allowsQuestions != false else { validationMessage = "Questions are turned off for this lesson."; return }
        guard questionText.count <= 1000 else { validationMessage = "Keep your question to 1,000 characters or fewer."; return }
        guard let answer = answerer.answer(question: questionText, lesson: lesson) else { return }
        answers.append(answer)
        progress.questionHistory = answers
        questionText = ""
        save()
    }

    func returnToPlayer() {
        route = .player
    }

    func choosePracticePhoto() {
        practice.mediaFilename = nil
        practice.mediaKind = .photo
        practice.mediaDuration = nil
        validationMessage = nil
    }

    func choosePracticeVideo(duration: TimeInterval = 45) {
        practice.mediaFilename = nil
        practice.mediaKind = .video
        practice.mediaDuration = duration
        validationMessage = nil
    }

    @discardableResult
    func submitPractice() -> Bool {
        if let error = practice.validationError {
            validationMessage = error
            return false
        }
        validationMessage = nil
        practice.submittedAt = .now
        progress.practice = practice
        save()
        route = .practiceFeedback
        return true
    }

    func sharePracticeWithFamily() {
        practice.isSharedWithFamily = true
        progress.practice = practice
        save()
    }

    func skipPractice() {
        guard canFinish else {
            validationMessage = "Complete every lesson step before finishing."
            return
        }
        finishLesson()
    }

    func finishLesson() {
        guard canFinish else {
            validationMessage = "Complete every lesson step before finishing."
            return
        }
        if progress.lifecycle != .completed {
            progress.lifecycle = .completed
            progress.completionCount += 1
            progress.completedAt = .now
            save()
        }
        route = .completion
    }

    func learnAgain() {
        progress.lifecycle = .ready
        progress.completedStepIDs = []
        progress.checkedMaterialIDs = []
        progress.currentStepIndex = 0
        progress.playbackPosition = lesson.steps.first?.start ?? 0
        progress.practice = .empty
        progress.passNumber += 1
        practice = .empty
        answers = []
        progress.questionHistory = []
        save()
        route = .materials
    }

    func showHistory() { route = .history }
    func showDashboard() { route = .dashboard }

    var learningRecords: [LearningProgress] { (try? store.loadAll()) ?? [] }

    func openHistoryLesson(_ id: String) {
        guard let selected = availableLessons.first(where: { $0.id == id }) else { return }
        load(selected, startImmediately: true)
    }

    func load(_ newLesson: LearningLesson, startImmediately: Bool = false) {
        lesson = newLesson
        let restored = try? store.load(for: newLesson.id)
        progress = restored.flatMap { $0.lessonID == newLesson.id && $0.revisionID == newLesson.revisionID ? $0 : nil }
            ?? LearningProgress.fresh(for: newLesson)
        practice = progress.practice
        answers = progress.questionHistory ?? []
        questionText = ""
        validationMessage = nil
        route = startImmediately
            ? (progress.lifecycle == .ready ? .materials : .player)
            : .dashboard
    }

    func clearLocalHistory() {
        try? store.delete()
        progress = .fresh(for: lesson)
        practice = .empty
        answers = []
        route = .dashboard
    }

    func showArchivedPractice(_ saved: PracticeSubmission) {
        progress.practice = saved
        practice = saved
        route = .practiceFeedback
    }

    func clearPractice() {
        progress.practice = .empty
        practice = .empty
    }

    private func save() {
        progress.updatedAt = .now
        try? store.save(progress)
        onProgressChanged?(progress)
    }
}
