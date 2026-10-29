import Foundation

enum CaptureRoute: Equatable {
    case entry
    case recording
    case details
    case processing
    case transcript
    case materials
    case steps
    case sharing
    case success
    case recovery
}

enum DraftLifecycle: String, Codable {
    case local
    case uploading
    case processing
    case needsReview
    case needsAttention
    case readyToPublish
    case publishing
    case published
    case cancelled
}

enum DraftProcessingStage: String, Codable, CaseIterable {
    case source
    case transcript
    case steps
    case keyframes
    case reviewPackage
}

enum DraftMetadataError: String, Codable, Equatable {
    case title
    case maker
    case language
}

struct TranscriptSegment: Codable, Equatable, Identifiable {
    let id: String
    var start: TimeInterval
    var end: TimeInterval
    var speaker: String
    var text: String
    var needsReview: Bool
}

struct LessonDraftItem: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var quantity: String
    var sourceTime: TimeInterval?
}

struct LessonDraftStep: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var instruction: String
    var start: TimeInterval
    var end: TimeInterval
    var keyframeName: String = "FamilyPaperCraft"
    var caution: String? = nil
    var keyMomentReviewed: Bool = true
}

struct CaptureDraft: Codable, Equatable {
    var id: String = "current-private-draft"
    var title = ""
    var maker = ""
    var language = ""
    var category = ""
    var familyStory = ""
    var keepOriginalVoice = true
    var sourceDuration: TimeInterval = 0
    var sourceMediaFilename: String? = nil
    var lifecycle: DraftLifecycle = .local
    var processingStage: DraftProcessingStage = .source
    var completedStages: Set<DraftProcessingStage> = []
    var transcript: [TranscriptSegment] = []
    var ingredients: [LessonDraftItem] = []
    var tools: [LessonDraftItem] = []
    var steps: [LessonDraftStep] = []
    var transcriptApproved = false
    var materialsApproved = false
    var stepsApproved = false
    var selectedCover = "FamilyPottery"
    var familyAccess = "View and Learn"
    var allowsQuestions = true

    static let empty = CaptureDraft()

    static func fresh() -> CaptureDraft {
        var draft = CaptureDraft()
        draft.id = UUID().uuidString.lowercased()
        return draft
    }

    static var sample: CaptureDraft {
        CaptureDraft(
            title: "Grandma's Dumplings",
            maker: "Grandma Mei",
            language: "English",
            category: "Family Recipes",
            familyStory: "Sunday dumplings have brought our family together for three generations.",
            sourceDuration: 128,
            lifecycle: .needsReview,
            processingStage: .reviewPackage,
            completedStages: Set(DraftProcessingStage.allCases),
            transcript: [
                TranscriptSegment(id: "t1", start: 0, end: 18, speaker: "Grandma Mei", text: "Start with flour and add the warm water slowly.", needsReview: false),
                TranscriptSegment(id: "t2", start: 18, end: 43, speaker: "Grandma Mei", text: "Knead until the dough feels smooth and soft.", needsReview: true),
                TranscriptSegment(id: "t3", start: 43, end: 84, speaker: "Grandma Mei", text: "Roll each wrapper thin at the edge and thicker in the center.", needsReview: false)
            ],
            ingredients: [
                LessonDraftItem(id: "i1", name: "All-purpose flour", quantity: "2 cups", sourceTime: 4),
                LessonDraftItem(id: "i2", name: "Warm water", quantity: "3/4 cup", sourceTime: 7),
                LessonDraftItem(id: "i3", name: "Family filling", quantity: "As needed", sourceTime: 62)
            ],
            tools: [
                LessonDraftItem(id: "tool1", name: "Mixing bowl", quantity: "", sourceTime: 2),
                LessonDraftItem(id: "tool2", name: "Rolling pin", quantity: "", sourceTime: 48)
            ],
            steps: [
                LessonDraftStep(id: "s1", title: "Mix the dough", instruction: "Add water slowly while mixing.", start: 0, end: 28),
                LessonDraftStep(id: "s2", title: "Knead until smooth", instruction: "Use the heel of your hand.", start: 28, end: 48),
                LessonDraftStep(id: "s3", title: "Roll the wrappers", instruction: "Keep the center slightly thicker.", start: 48, end: 84, keyMomentReviewed: false),
                LessonDraftStep(id: "s4", title: "Fill and fold", instruction: "Pinch the seam closed.", start: 84, end: 128)
            ],
            selectedCover: "EchoHero"
        )
    }

    var metadataErrors: [DraftMetadataError] {
        var errors: [DraftMetadataError] = []
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMaker = maker.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedTitle.isEmpty || normalizedTitle.count > 120 { errors.append(.title) }
        if normalizedMaker.isEmpty || normalizedMaker.count > 80 { errors.append(.maker) }
        if normalizedLanguage.isEmpty || normalizedLanguage.count > 60 { errors.append(.language) }
        return errors
    }

    var hasValidStepRanges: Bool {
        guard !steps.isEmpty else { return false }
        for (index, step) in steps.enumerated() {
            guard step.start >= 0, step.end > step.start, step.end <= sourceDuration else { return false }
            if index > 0, step.start < steps[index - 1].end { return false }
        }
        return true
    }

    mutating func setSourceDuration(_ duration: TimeInterval) {
        sourceDuration = min(max(duration, 0), 600)
    }
}
