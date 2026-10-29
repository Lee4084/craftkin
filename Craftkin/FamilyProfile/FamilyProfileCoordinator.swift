import Foundation
import Combine

@MainActor
final class FamilyProfileCoordinator: ObservableObject {
    @Published private(set) var state: FamilyProfileState
    @Published var route: FamilyProfileRoute = .familyOverview
    @Published var notice: String?
    @Published var handoff: FamilyAppHandoff?
    @Published private(set) var librarySkills: [SkillLesson] = []
    @Published private(set) var exportURL: URL?
    @Published private(set) var profileEditError: String?
    var exportDataProvider: ((Bool) throws -> Data)?
    var deletePracticesHandler: (() throws -> Void)?
    var deleteLocalDataHandler: (() throws -> Void)?
    private let store: any FamilyProfileStateStore
    private let learningHistoryStore: (any LearningProgressStoring)?
    private let useExampleData: Bool
    private let mediaStore: LocalMediaStore
    var onLearningHistoryDeleted: (() -> Void)?

    init(
        store: any FamilyProfileStateStore,
        learningHistoryStore: (any LearningProgressStoring)? = nil,
        initialFamilyName: String? = nil,
        useExampleData: Bool = true,
        mediaStore: LocalMediaStore = LocalMediaStore()
    ) {
        self.store = store
        self.useExampleData = useExampleData
        self.mediaStore = mediaStore
        self.learningHistoryStore = learningHistoryStore
        if let restored = try? store.load() {
            state = restored
        } else {
            var initial = FamilyProfileState.sample
            if !useExampleData {
                initial.members = initial.members.filter(\.isCurrentUser)
                initial.members[0].name = "You"
                initial.members[0].email = ""
                initial.invitations = []
                initial.activities = []
                initial.sharedLessonCount = 0
                initial.sharedPracticeCount = 0
                initial.completedSkillCount = 0
                initial.ownedLessonsNeedingTransfer = 0
                initial.familyName = "My Family"
            }
            if let initialFamilyName, !initialFamilyName.isEmpty { initial.familyName = initialFamilyName }
            state = initial
        }
    }

    var occupiedFamilySlots: Int { state.members.count + state.invitations.count }
    var visibleActivity: [FamilyActivityEvent] {
        state.activities.filter(\.isSharedWithFamily).map { event in
            guard useExampleData, event.sourceID == nil, event.lessonID == nil else { return event }
            // Exact legacy fixture signatures only; real events have source/lesson IDs.
            let lessonID: String
            switch (event.memberName, event.summary, event.kind, event.age, event.imageName) {
            case ("Emma Carter", "shared a practice for Grandma’s Apple Pie.", .sharedPractice, "2h ago", let image) where ["EchoHero", "EchoReview"].contains(image):
                lessonID = "garden"
            case ("Rose Carter", "published Grandma’s Apple Pie.", .newLesson, "5h ago", let image) where ["EchoHero", "EchoHome"].contains(image):
                lessonID = "wreath"
            case ("Daniel Carter", "completed Dad’s Bike Repair.", .milestone, "2d ago", let image) where ["SkillBikeRepair", "EchoWoodwork"].contains(image):
                lessonID = "bike-repair"
            default: return event
            }
            guard let example = FamilyProfileState.sample.activities.first(where: { $0.lessonID == lessonID }) else { return event }
            var displayed = event
            displayed.summary = example.summary
            displayed.imageName = example.imageName
            displayed.lessonID = example.lessonID
            return displayed
        }
    }
    var currentUser: FamilyMember? { state.members.first(where: \.isCurrentUser) }
    var latestLearningProgress: LearningProgress? { try? learningHistoryStore?.load() }
    var latestLearningSkill: SkillLesson? { librarySkills.first { $0.id == latestLearningProgress?.lessonID } }

    func synchronizeLibrary(_ skills: [SkillLesson]) {
        librarySkills = skills
        state.sharedLessonCount = skills.count
        persist()
    }

    @discardableResult
    func updateProfile(name: String, avatarData: Data? = nil, removeAvatar: Bool = false) -> Bool {
        profileEditError = nil
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 80,
              let index = state.members.firstIndex(where: \.isCurrentUser) else {
            profileEditError = "Enter a name of 1 to 80 characters."
            return false
        }
        var updated = state
        let previousPhoto = updated.members[index].avatarFilename
        var newPhoto: String?
        do {
            updated.members[index].name = normalized
            if let avatarData {
                newPhoto = try mediaStore.save(ProfilePhotoProcessor.jpeg(from: avatarData), extension: "jpg")
                updated.members[index].avatarFilename = newPhoto
            } else if removeAvatar {
                updated.members[index].avatarFilename = nil
            }
            try store.save(updated)
            state = updated
            if let previousPhoto, previousPhoto != updated.members[index].avatarFilename,
               !updated.members.contains(where: { $0.avatarFilename == previousPhoto }) {
                try? mediaStore.delete(previousPhoto)
            }
            return true
        } catch {
            if let newPhoto { try? mediaStore.delete(newPhoto) }
            profileEditError = (error as? ProfilePhotoError)?.errorDescription ?? "Your profile could not be saved. Please try again."
            return false
        }
    }

    func show(_ destination: FamilyProfileRoute) { route = destination }
    func showFamily() { route = .familyOverview }
    func showProfile() { route = .profile }

    func sendInvitation(email: String, name: String?, role: FamilyAccessRole = .viewAndLearn) -> InvitationResult {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil else { return .invalidEmail }
        guard !state.invitations.contains(where: { $0.email == normalized }) else { return .alreadyPending }
        guard occupiedFamilySlots < 5 else { return .familyFull }
        state.invitations.append(FamilyInvitation(email: normalized, displayName: name, role: role))
        persist()
        return .sent
    }

    func resendInvitation(_ id: UUID) {
        guard let index = state.invitations.firstIndex(where: { $0.id == id }) else { return }
        let old = state.invitations[index]
        state.invitations[index] = FamilyInvitation(email: old.email, displayName: old.displayName, role: old.role)
        notice = "A fresh private invitation is ready. The earlier link no longer works."
        persist()
    }

    func cancelInvitation(_ id: UUID) {
        state.invitations.removeAll { $0.id == id }
        persist()
    }

    func updateRole(for id: UUID, to role: FamilyAccessRole) -> MemberUpdateResult {
        guard let index = state.members.firstIndex(where: { $0.id == id }) else { return .notFound }
        if state.members[index].role == .organizer, role != .organizer,
           state.members.filter({ $0.role == .organizer }).count == 1 { return .lastOrganizer }
        state.members[index].role = role
        persist()
        return .saved
    }

    func updateLessonAccess(for id: UUID, mode: LessonAccessMode, lessonIDs: Set<String>) -> MemberUpdateResult {
        guard let index = state.members.firstIndex(where: { $0.id == id }) else { return .notFound }
        guard mode != .selected || !lessonIDs.isEmpty else { return .selectionRequired }
        state.members[index].lessonAccess = mode
        state.members[index].selectedLessonIDs = lessonIDs
        persist()
        return .saved
    }

    func updatePermissions(for id: UUID, publish: Bool, edit: Bool, invite: Bool, download: Bool) {
        guard let index = state.members.firstIndex(where: { $0.id == id }) else { return }
        state.members[index].canPublish = publish
        state.members[index].canEditOwnLessons = edit
        state.members[index].canInvite = invite
        state.members[index].canDownloadOriginals = download
        persist()
    }

    func removeMember(_ id: UUID) -> MemberUpdateResult {
        guard let member = state.members.first(where: { $0.id == id }) else { return .notFound }
        if member.role == .organizer, state.members.filter({ $0.role == .organizer }).count == 1 { return .lastOrganizer }
        state.members.removeAll { $0.id == id }
        persist()
        return .saved
    }

    func setNotification(_ keyPath: WritableKeyPath<FamilySettings, Bool>, enabled: Bool) {
        state.settings[keyPath: keyPath] = enabled
        persist()
    }
    func setCreateDraftsWithAI(_ enabled: Bool) { state.settings.createDraftsWithAI = enabled; persist() }
    func setShowLockScreenDetails(_ enabled: Bool) { state.settings.showLockScreenDetails = enabled; persist() }
    func setWiFiOnly(_ enabled: Bool) { state.settings.downloadOnWiFiOnly = enabled; persist() }
    func removeDownloads() { state.downloadsRemoved = true; persist(); notice = "There are no downloaded playback copies to remove. Your source videos and practice attachments are kept." }
    func prepareExport(includeMedia: Bool) {
        exportURL = nil
        do {
            let data: Data
            if let exportDataProvider { data = try exportDataProvider(includeMedia) }
            else { data = try LocalExportBuilder().make(profile: currentUser, familyName: state.familyName,
                                                        settings: state.settings, lessons: [],
                                                        progress: (try? learningHistoryStore?.loadAll()) ?? [], includeMedia: includeMedia) }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("EchoSkill-Export-\(UUID().uuidString).json")
            try data.write(to: url, options: .atomic)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            #endif
            exportURL = url
            state.exportPrepared = true
            persist()
            notice = "Your local export is ready. Use Save or Share Export to choose where it goes."
        } catch {
            state.exportPrepared = false
            notice = error.localizedDescription
        }
    }
    func deleteLearningHistory() {
        do {
            try learningHistoryStore?.delete()
        } catch {
            notice = "Your learning history could not be removed. Please try again."
            return
        }
        state.completedSkillCount = 0
        persist()
        onLearningHistoryDeleted?()
        notice = "Your private learning history was removed. Family lessons and practices remain."
    }

    func deletePractices() {
        do {
            try deletePracticesHandler?()
            state.activities.removeAll { $0.kind == .sharedPractice }
            state.sharedPracticeCount = 0
            persist()
            notice = "Your saved practices were removed. Lesson progress and source lessons are unchanged."
        } catch { notice = "Practices could not be removed. Please try again." }
    }

    func deleteLocalData(confirmation: String) {
        guard confirmation == "DELETE" else { notice = "Type DELETE exactly."; return }
        do { try deleteLocalDataHandler?() }
        catch { notice = "Some local data could not be removed. Please try again." }
    }

    func recordPublishedLesson(_ draft: CaptureDraft) {
        guard draft.lifecycle == .published,
              !state.activities.contains(where: { $0.sourceID == "lesson-\(draft.id)" }) else { return }
        state.sharedLessonCount += 1
        state.activities.insert(
            FamilyActivityEvent(
                memberName: draft.maker,
                summary: "published \(draft.title).",
                kind: .newLesson,
                age: "now",
                isSharedWithFamily: true,
                imageName: draft.selectedCover
            ),
            at: 0
        )
        state.activities[0].sourceID = "lesson-\(draft.id)"
        state.activities[0].lessonID = draft.id
        persist()
    }

    func synchronizeLearningHistory(_ records: [LearningProgress]) {
        state.completedSkillCount = records.filter { $0.completionCount > 0 }.count
        persist()
    }

    func apply(_ progress: LearningProgress, lessonTitle: String? = nil) {
        if progress.lifecycle == .completed {
            state.completedSkillCount = max(state.completedSkillCount, progress.completionCount)
        }
        let practiceID = "practice-\(progress.lessonID)-\(progress.practice.submittedAt?.timeIntervalSince1970 ?? 0)"
        if progress.practice.isSharedWithFamily,
           !state.activities.contains(where: { $0.sourceID == practiceID }) {
            state.sharedPracticeCount += 1
            state.activities.insert(
                FamilyActivityEvent(
                    memberName: currentUser?.name ?? "A family member",
                    summary: "shared a practice for \(lessonTitle ?? "a family lesson").",
                    kind: .sharedPractice,
                    age: "now",
                    isSharedWithFamily: true,
                    imageName: librarySkills.first(where: { $0.id == progress.lessonID })?.coverImageName ?? "FamilyPaperCraft"
                ),
                at: 0
            )
            state.activities[0].sourceID = practiceID
            state.activities[0].lessonID = progress.lessonID
        }
        persist()
    }
    func resolveOwnedLessonTransfer() { state.ownedLessonsNeedingTransfer = 0; persist() }

    func requestAccountDeletion(typedConfirmation: String, authenticated: Bool) -> AccountDeletionResult {
        if state.deletionScheduledAt != nil { return .alreadyScheduled }
        guard state.ownedLessonsNeedingTransfer == 0 else { return .ownedLessonsNeedTransfer }
        guard typedConfirmation == "DELETE" else { return .confirmationMismatch }
        guard authenticated else { return .authenticationRequired }
        state.deletionScheduledAt = Date()
        persist()
        return .scheduled
    }

    private func persist() { try? store.save(state) }
}
