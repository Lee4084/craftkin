import Foundation

enum FamilyAccessRole: String, Codable, CaseIterable, Identifiable {
    case viewAndLearn
    case contributor
    case organizer

    var id: String { rawValue }
    var title: String {
        switch self {
        case .viewAndLearn: "View and learn"
        case .contributor: "Can contribute"
        case .organizer: "Organizer"
        }
    }
}

enum LessonAccessMode: String, Codable, CaseIterable, Identifiable {
    case all
    case selected
    var id: String { rawValue }
}

struct FamilyMember: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var email: String
    var relation: String
    var role: FamilyAccessRole
    var isMaker: Bool
    var isCurrentUser: Bool
    var imageName: String
    var avatarFilename: String?
    var lessonAccess: LessonAccessMode
    var selectedLessonIDs: Set<String>
    var canPublish: Bool
    var canEditOwnLessons: Bool
    var canInvite: Bool
    var canDownloadOriginals: Bool

    init(
        id: UUID = UUID(), name: String, email: String, relation: String,
        role: FamilyAccessRole, isMaker: Bool = false, isCurrentUser: Bool = false,
        imageName: String, lessonAccess: LessonAccessMode = .all,
        selectedLessonIDs: Set<String> = [], canPublish: Bool = false,
        canEditOwnLessons: Bool = false, canInvite: Bool = false,
        canDownloadOriginals: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.relation = relation
        self.role = role
        self.isMaker = isMaker
        self.isCurrentUser = isCurrentUser
        self.imageName = imageName
        self.lessonAccess = lessonAccess
        self.selectedLessonIDs = selectedLessonIDs
        self.canPublish = canPublish
        self.canEditOwnLessons = canEditOwnLessons
        self.canInvite = canInvite
        self.canDownloadOriginals = canDownloadOriginals
    }
}

struct FamilyInvitation: Codable, Equatable, Identifiable {
    let id: UUID
    var email: String
    var displayName: String?
    var role: FamilyAccessRole
    let createdAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(), email: String, displayName: String?,
        role: FamilyAccessRole = .viewAndLearn, createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.role = role
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(7 * 24 * 60 * 60)
    }
}

enum FamilyActivityKind: String, Codable, CaseIterable {
    case newLesson
    case sharedPractice
    case milestone
    case updatedLesson
    case privateQuestion
    case privateProgress
}

struct FamilyActivityEvent: Codable, Equatable, Identifiable {
    let id: UUID
    var sourceID: String?
    var lessonID: String?
    var memberName: String
    var summary: String
    var kind: FamilyActivityKind
    var age: String
    var isSharedWithFamily: Bool
    var imageName: String

    init(id: UUID = UUID(), memberName: String, summary: String, kind: FamilyActivityKind, age: String, isSharedWithFamily: Bool, imageName: String, lessonID: String? = nil) {
        self.id = id
        self.lessonID = lessonID
        self.memberName = memberName
        self.summary = summary
        self.kind = kind
        self.age = age
        self.isSharedWithFamily = isSharedWithFamily
        self.imageName = imageName
    }
}

enum PracticeSharingPreference: String, Codable { case askEveryTime, privateByDefault }

struct FamilySettings: Codable, Equatable {
    var returnToLesson = true
    var processingComplete = true
    var practiceFeedback = true
    var newFamilyLessons = true
    var sharedPractices = true
    var familyComments = true
    var memberInvitations = true
    var showLockScreenDetails = false
    var createDraftsWithAI = true
    var improveAI = false
    var practiceSharing: PracticeSharingPreference = .askEveryTime
    var downloadOnWiFiOnly = true
    var keepOriginalsDays = 30
}

struct FamilyProfileState: Codable, Equatable {
    var familyName: String
    var members: [FamilyMember]
    var invitations: [FamilyInvitation]
    var activities: [FamilyActivityEvent]
    var settings: FamilySettings
    var sharedLessonCount: Int
    var sharedPracticeCount: Int
    var completedSkillCount: Int
    var ownedLessonsNeedingTransfer: Int
    var deletionScheduledAt: Date?
    var downloadsRemoved: Bool
    var exportPrepared: Bool

    static let sample = FamilyProfileState(
        familyName: "The Carter Family",
        members: [
            FamilyMember(name: "Emma Carter", email: "emma@example.com", relation: "You", role: .organizer, isCurrentUser: true, imageName: "FamilyCooking", canPublish: true, canEditOwnLessons: true, canInvite: true, canDownloadOriginals: true),
            FamilyMember(name: "Rose Carter", email: "rose@example.com", relation: "Grandma", role: .contributor, isMaker: true, imageName: "FamilySewing", canPublish: true, canEditOwnLessons: true),
            FamilyMember(name: "Daniel Carter", email: "daniel@example.com", relation: "Dad", role: .contributor, imageName: "SkillBikeRepair", canPublish: true, canEditOwnLessons: true),
            FamilyMember(name: "Henry Carter", email: "henry@example.com", relation: "Grandpa", role: .viewAndLearn, isMaker: true, imageName: "SkillWoodwork")
        ],
        invitations: [],
        activities: [
            FamilyActivityEvent(memberName: "Emma Carter", summary: "shared a practice for Grandpa’s Garden Cuttings.", kind: .sharedPractice, age: "2h ago", isSharedWithFamily: true, imageName: "SkillGardening", lessonID: "garden"),
            FamilyActivityEvent(memberName: "Rose Carter", summary: "published Holiday Wreath Making.", kind: .newLesson, age: "5h ago", isSharedWithFamily: true, imageName: "SkillWreath", lessonID: "wreath"),
            FamilyActivityEvent(memberName: "Daniel Carter", summary: "completed Dad’s Bike Repair.", kind: .milestone, age: "2d ago", isSharedWithFamily: true, imageName: "SkillBikeRepair", lessonID: "bike-repair"),
            FamilyActivityEvent(memberName: "Emma Carter", summary: "asked a private question.", kind: .privateQuestion, age: "now", isSharedWithFamily: false, imageName: "FamilyCooking")
        ],
        settings: FamilySettings(),
        sharedLessonCount: 8,
        sharedPracticeCount: 4,
        completedSkillCount: 3,
        ownedLessonsNeedingTransfer: 2,
        deletionScheduledAt: nil,
        downloadsRemoved: false,
        exportPrepared: false
    )
}

enum InvitationResult: Equatable { case sent, invalidEmail, familyFull, alreadyPending }
enum MemberUpdateResult: Equatable { case saved, lastOrganizer, selectionRequired, notFound }
enum AccountDeletionResult: Equatable { case ownedLessonsNeedTransfer, confirmationMismatch, authenticationRequired, scheduled, alreadyScheduled }

enum FamilyProfileRoute: Equatable {
    case familyOverview, members, inviteMember, memberPermissions(UUID), familyActivity, makerArchive
    case profile, settings, storage, notifications, privacy, manageData, accountDeletion, help
}

enum FamilyAppHandoff: Equatable {
    case learningHistory, learn(String), library, capture, practice(String)
}
