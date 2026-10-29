import Foundation
import Testing
@testable import Craftkin

@MainActor
struct FamilySpaceTests {
    @Test("Example activities use distinct matching lessons and real covers")
    func variedExampleActivities() throws {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())
        let lessons = LocalSampleSkillRepository(state: .populated).skills
        #expect(Set(coordinator.visibleActivity.compactMap(\.lessonID)).count == 3)
        for event in coordinator.visibleActivity {
            let lesson = try #require(lessons.first { $0.id == event.lessonID })
            #expect(event.summary.contains(lesson.title))
            #expect(event.imageName == lesson.coverImageName)
        }
    }

    @Test("Legacy demo refresh preserves real activity, private records and storage")
    func legacyExampleActivityDisplay() throws {
        let old = FamilyActivityEvent(memberName: "Emma Carter", summary: "shared a practice for Grandma’s Apple Pie.", kind: .sharedPractice, age: "2h ago", isSharedWithFamily: true, imageName: "EchoHero")
        var real = old
        real.sourceID = "practice-apple-pie-123"
        real.lessonID = "apple-pie"
        var privateEvent = old
        privateEvent.isSharedWithFamily = false
        var seed = FamilyProfileState.sample
        seed.activities = [old, real, privateEvent]
        let store = InMemoryFamilyProfileStore(seed: seed)
        let coordinator = FamilyProfileCoordinator(store: store)
        #expect(coordinator.visibleActivity[0].lessonID == "garden")
        #expect(coordinator.visibleActivity[0].id == old.id)
        #expect(coordinator.visibleActivity[1] == real)
        #expect(coordinator.visibleActivity.count == 2)
        #expect(try store.load() == seed)
        let noDemo = FamilyProfileCoordinator(store: store, useExampleData: false)
        #expect(noDemo.visibleActivity[0] == old)
    }

    @Test("Other exact legacy fixtures refresh without rewriting custom summaries")
    func otherLegacyActivityExamples() throws {
        let rose = FamilyActivityEvent(memberName: "Rose Carter", summary: "published Grandma’s Apple Pie.", kind: .newLesson, age: "5h ago", isSharedWithFamily: true, imageName: "EchoHome")
        let dad = FamilyActivityEvent(memberName: "Daniel Carter", summary: "completed Dad’s Bike Repair.", kind: .milestone, age: "2d ago", isSharedWithFamily: true, imageName: "EchoWoodwork")
        var custom = rose
        custom.summary = "published a personal lesson."
        var state = FamilyProfileState.sample
        state.activities = [rose, dad, custom]
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore(seed: state))
        #expect(coordinator.visibleActivity[0].lessonID == "wreath")
        #expect(coordinator.visibleActivity[0].imageName == "SkillWreath")
        #expect(coordinator.visibleActivity[1].lessonID == "bike-repair")
        #expect(coordinator.visibleActivity[2] == custom)
    }

    @Test("Invitations validate email, use safe access, and remain idempotent")
    func invitationSafety() throws {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())

        #expect(coordinator.sendInvitation(email: "not-an-email", name: "Alex") == .invalidEmail)
        #expect(coordinator.sendInvitation(email: "alex@example.com", name: "Alex") == .sent)
        #expect(coordinator.state.invitations.count == 1)
        #expect(coordinator.state.invitations[0].role == .viewAndLearn)
        #expect(coordinator.sendInvitation(email: " ALEX@example.com ", name: "Alex") == .alreadyPending)
        #expect(coordinator.state.invitations.count == 1)
    }

    @Test("Accepted members and pending invitations share the five-person limit")
    func familyCapacity() {
        var state = FamilyProfileState.sample
        state.invitations = [FamilyInvitation(email: "pending@example.com", displayName: nil)]
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore(seed: state))

        #expect(coordinator.occupiedFamilySlots == 5)
        #expect(coordinator.sendInvitation(email: "new@example.com", name: nil) == .familyFull)
    }

    @Test("Resending supersedes the old invitation and cancellation is immediate")
    func invitationLifecycle() throws {
        var state = FamilyProfileState.sample
        state.members.removeLast()
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore(seed: state))
        #expect(coordinator.sendInvitation(email: "alex@example.com", name: nil) == .sent)
        let first = try #require(coordinator.state.invitations.first)

        coordinator.resendInvitation(first.id)
        let replacement = try #require(coordinator.state.invitations.first)
        #expect(replacement.id != first.id)
        #expect(replacement.expiresAt.timeIntervalSince(replacement.createdAt) == 7 * 24 * 60 * 60)

        coordinator.cancelInvitation(replacement.id)
        #expect(coordinator.state.invitations.isEmpty)
    }

    @Test("The final organizer cannot demote or remove themselves")
    func protectsFinalOrganizer() throws {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())
        let current = try #require(coordinator.state.members.first(where: { $0.isCurrentUser }))

        #expect(coordinator.updateRole(for: current.id, to: .contributor) == .lastOrganizer)
        #expect(coordinator.removeMember(current.id) == .lastOrganizer)
        #expect(coordinator.state.members.first(where: { $0.id == current.id })?.role == .organizer)
    }

    @Test("Selected lesson access requires at least one lesson")
    func selectedLessonsRequireSelection() throws {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())
        let rose = try #require(coordinator.state.members.first(where: { $0.name == "Rose Carter" }))

        #expect(coordinator.updateLessonAccess(for: rose.id, mode: .selected, lessonIDs: []) == .selectionRequired)
        #expect(coordinator.updateLessonAccess(for: rose.id, mode: .selected, lessonIDs: ["apple-pie"]) == .saved)
    }

    @Test("Family Activity excludes private learning details")
    func activityPrivacy() {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())
        let everyEventIsShared = coordinator.visibleActivity.allSatisfy { $0.isSharedWithFamily }
        #expect(everyEventIsShared)
        #expect(!coordinator.visibleActivity.contains(where: { $0.kind == .privateQuestion || $0.kind == .privateProgress }))
    }

    @Test("Member edits, removal, and navigation persist their exact scope")
    func memberAdministration() throws {
        let store = InMemoryFamilyProfileStore()
        let coordinator = FamilyProfileCoordinator(store: store)
        let daniel = try #require(coordinator.state.members.first(where: { $0.name == "Daniel Carter" }))

        coordinator.show(.members)
        #expect(coordinator.route == .members)
        #expect(coordinator.updateRole(for: daniel.id, to: .viewAndLearn) == .saved)
        coordinator.updatePermissions(for: daniel.id, publish: false, edit: false, invite: true, download: true)
        let updated = try #require(coordinator.state.members.first(where: { $0.id == daniel.id }))
        #expect(updated.canInvite)
        #expect(updated.canDownloadOriginals)
        #expect(coordinator.removeMember(daniel.id) == .saved)
        #expect(coordinator.removeMember(daniel.id) == .notFound)
        #expect(coordinator.updateRole(for: UUID(), to: .organizer) == .notFound)
        #expect(coordinator.updateLessonAccess(for: UUID(), mode: .all, lessonIDs: []) == .notFound)
    }
}

@MainActor
struct FamilySettingsTests {
    @Test("Privacy-preserving defaults survive persistence")
    func settingsRoundTrip() throws {
        let store = InMemoryFamilyProfileStore()
        let coordinator = FamilyProfileCoordinator(store: store)
        #expect(!coordinator.state.settings.showLockScreenDetails)
        #expect(coordinator.state.settings.practiceSharing == .askEveryTime)
        #expect(!coordinator.state.settings.improveAI)

        coordinator.setNotification(\.sharedPractices, enabled: false)
        coordinator.setCreateDraftsWithAI(false)

        let restored = FamilyProfileCoordinator(store: store)
        #expect(!restored.state.settings.sharedPractices)
        #expect(!restored.state.settings.createDraftsWithAI)
    }

    @Test("Deleting learning history leaves shared lessons and practices intact")
    func deletesOnlyLearningHistory() {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())
        let lessonCount = coordinator.state.sharedLessonCount
        let practiceCount = coordinator.state.sharedPracticeCount

        coordinator.deleteLearningHistory()

        #expect(coordinator.state.completedSkillCount == 0)
        #expect(coordinator.state.sharedLessonCount == lessonCount)
        #expect(coordinator.state.sharedPracticeCount == practiceCount)
    }

    @Test("Account deletion needs resolved ownership, DELETE, and authentication")
    func deletionGuardrails() {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())
        #expect(coordinator.requestAccountDeletion(typedConfirmation: "DELETE", authenticated: true) == .ownedLessonsNeedTransfer)

        coordinator.resolveOwnedLessonTransfer()
        #expect(coordinator.requestAccountDeletion(typedConfirmation: "delete", authenticated: true) == .confirmationMismatch)
        #expect(coordinator.requestAccountDeletion(typedConfirmation: "DELETE", authenticated: false) == .authenticationRequired)
        #expect(coordinator.requestAccountDeletion(typedConfirmation: "DELETE", authenticated: true) == .scheduled)
        #expect(coordinator.requestAccountDeletion(typedConfirmation: "DELETE", authenticated: true) == .alreadyScheduled)
    }

    @Test("Local storage and export controls report only actions they performed")
    func localControls() {
        let coordinator = FamilyProfileCoordinator(store: InMemoryFamilyProfileStore())
        coordinator.setShowLockScreenDetails(true)
        coordinator.setWiFiOnly(false)
        coordinator.removeDownloads()
        coordinator.prepareExport(includeMedia: true)

        #expect(coordinator.state.settings.showLockScreenDetails)
        #expect(!coordinator.state.settings.downloadOnWiFiOnly)
        #expect(coordinator.state.downloadsRemoved)
        #expect(coordinator.state.exportPrepared)
        #expect(coordinator.notice?.contains("local export") == true)
    }

    @Test("UserDefaults family state round-trips and clears")
    func userDefaultsRoundTrip() throws {
        let suiteName = "FamilyProfileTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsFamilyProfileStore(defaults: defaults)

        try store.save(.sample)
        #expect(try store.load() == .sample)
        try store.delete()
        #expect(try store.load() == nil)
    }
}
