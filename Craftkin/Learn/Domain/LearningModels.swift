import Foundation

enum LearningRoute: Equatable {
    case dashboard
    case materials
    case player
    case questionAnswer
    case practiceSubmission
    case practiceFeedback
    case completion
    case history
}

enum LearningLifecycle: String, Codable, Equatable {
    case ready
    case inProgress
    case completed
}

struct LearningMaterial: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let detail: String
}

struct LearningStep: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let instruction: String
    let familyTip: String?
    let sourceLabel: String
    let start: TimeInterval
    let end: TimeInterval
}

struct LessonKnowledge: Identifiable, Codable, Equatable {
    let id: String
    let keywords: [String]
    let answer: String
    let source: String
}

struct LearningLesson: Identifiable, Codable, Equatable {
    let id: String
    let revisionID: String
    let title: String
    let makerName: String
    let makerRelation: String
    let imageName: String
    let durationMinutes: Int
    let materials: [LearningMaterial]
    let steps: [LearningStep]
    let knowledge: [LessonKnowledge]
    var sourceMediaFilename: String? = nil
    var allowsQuestions: Bool? = nil

    static let sample = LearningLesson(
        id: "apple-pie",
        revisionID: "apple-pie-r1",
        title: "Grandma’s Apple Pie",
        makerName: "Margaret Carter",
        makerRelation: "Grandma",
        imageName: "FamilyBaking",
        durationMinutes: 18,
        materials: [
            LearningMaterial(id: "apples", name: "6 crisp apples", detail: "Granny Smith or Honeycrisp"),
            LearningMaterial(id: "dough", name: "2 rounds of pie dough", detail: "Chilled, not frozen"),
            LearningMaterial(id: "sugar", name: "3/4 cup brown sugar", detail: "Lightly packed"),
            LearningMaterial(id: "cinnamon", name: "1 tsp cinnamon", detail: "Plus a pinch of salt"),
            LearningMaterial(id: "dish", name: "9-inch pie dish", detail: "And a rolling pin")
        ],
        steps: [
            LearningStep(id: "pie-1", title: "Chill the dough", instruction: "Keep both rounds cold while you prepare the filling.", familyTip: "Cold dough makes the crust tender.", sourceLabel: "Grandma’s note · Step 1", start: 0, end: 42),
            LearningStep(id: "pie-2", title: "Peel the apples", instruction: "Peel, core, and cut the apples into even slices.", familyTip: "Even slices soften at the same pace.", sourceLabel: "Grandma’s note · Step 2", start: 42, end: 91),
            LearningStep(id: "pie-3", title: "Season the filling", instruction: "Toss the apples with brown sugar, cinnamon, and salt.", familyTip: "Use your hands so every slice is coated.", sourceLabel: "Grandma’s note · Step 3", start: 91, end: 139),
            LearningStep(id: "pie-4", title: "Line the pie dish", instruction: "Roll the first dough round and settle it into the dish without stretching.", familyTip: nil, sourceLabel: "Grandma’s note · Step 4", start: 139, end: 201),
            LearningStep(id: "pie-5", title: "Fill the pie", instruction: "Mound the apples in the center and tuck the smallest pieces around the edge.", familyTip: nil, sourceLabel: "Grandma’s note · Step 5", start: 201, end: 246),
            LearningStep(id: "pie-6", title: "Weave the lattice", instruction: "Lay alternating strips across the filling and leave small gaps between them.", familyTip: "The gaps let steam escape so the crust stays crisp.", sourceLabel: "Grandma’s note · Step 6", start: 246, end: 331),
            LearningStep(id: "pie-7", title: "Seal the edge", instruction: "Press the two crusts together, then crimp the edge gently.", familyTip: nil, sourceLabel: "Grandma’s note · Step 7", start: 331, end: 386),
            LearningStep(id: "pie-8", title: "Bake and rest", instruction: "Bake until deep golden, then let the pie rest before slicing.", familyTip: "Resting keeps the filling from running.", sourceLabel: "Grandma’s note · Step 8", start: 386, end: 470)
        ],
        knowledge: [
            LessonKnowledge(id: "steam", keywords: ["gap", "gaps", "lattice", "steam", "crisp"], answer: "Leave small gaps in the lattice so steam can escape and the crust stays crisp.", source: "Grandma’s note · Step 6"),
            LessonKnowledge(id: "dough", keywords: ["dough", "crust", "cold", "chill"], answer: "Keep the dough cold and avoid stretching it when you line the dish.", source: "Grandma’s note · Steps 1 and 4"),
            LessonKnowledge(id: "rest", keywords: ["rest", "slice", "filling", "run"], answer: "Let the baked pie rest before slicing so the filling can settle.", source: "Grandma’s note · Step 8")
        ]
    )
}

enum PracticeMediaKind: String, Codable, Equatable {
    case photo
    case video
}

struct PracticeSubmission: Codable, Equatable {
    var mediaFilename: String? = nil
    var mediaKind: PracticeMediaKind?
    var mediaDuration: TimeInterval?
    var note: String
    var isSharedWithFamily: Bool
    var submittedAt: Date?

    static let empty = PracticeSubmission(
        mediaKind: nil,
        mediaDuration: nil,
        note: "",
        isSharedWithFamily: false,
        submittedAt: nil
    )

    var validationError: String? {
        guard mediaKind != nil else { return "Add one photo or video before submitting." }
        if mediaKind == .video, (mediaDuration ?? 0) > 60 {
            return "Choose a video that is 60 seconds or shorter."
        }
        if note.count > 500 {
            return "Keep your note to 500 characters or fewer."
        }
        return nil
    }
}

struct LearningProgress: Codable, Equatable {
    var questionHistory: [GroundedAnswer]? = nil
    let lessonID: String
    let revisionID: String
    var lifecycle: LearningLifecycle
    var completedStepIDs: Set<String>
    var checkedMaterialIDs: Set<String>
    var currentStepIndex: Int
    var playbackPosition: TimeInterval
    var practice: PracticeSubmission
    var passNumber: Int
    var completionCount: Int
    var completedAt: Date?
    var updatedAt: Date
    var isPrivate: Bool

    static func fresh(for lesson: LearningLesson) -> LearningProgress {
        LearningProgress(
            lessonID: lesson.id,
            revisionID: lesson.revisionID,
            lifecycle: .ready,
            completedStepIDs: [],
            checkedMaterialIDs: [],
            currentStepIndex: 0,
            playbackPosition: lesson.steps.first?.start ?? 0,
            practice: .empty,
            passNumber: 1,
            completionCount: 0,
            completedAt: nil,
            updatedAt: .now,
            isPrivate: true
        )
    }
}

struct GroundedAnswer: Identifiable, Equatable, Codable {
    var id = UUID()
    let question: String
    let text: String
    let sources: [String]
}

struct GroundedLessonAnswerer {
    func answer(question: String, lesson: LearningLesson) -> GroundedAnswer? {
        let normalized = question
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if let fact = lesson.knowledge.first(where: { item in
            item.keywords.contains { normalized.contains($0.lowercased()) }
        }) {
            return GroundedAnswer(question: question, text: fact.answer, sources: [fact.source])
        }
        return GroundedAnswer(
            question: question,
            text: "This lesson doesn't mention that.",
            sources: []
        )
    }
}
