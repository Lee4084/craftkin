import Foundation
import Testing
@testable import Craftkin

@MainActor
struct OnboardingCoordinatorTests {
    @Test("A new coordinator starts at Welcome")
    func startsAtWelcome() {
        let coordinator = OnboardingCoordinator(
            completionStore: InMemoryOnboardingCompletionStore()
        )

        #expect(coordinator.step == .welcome)
        #expect(coordinator.canGoBack == false)
    }

    @Test("A completed coordinator restores the completion handoff")
    func restoresCompletedState() {
        let store = InMemoryOnboardingCompletionStore(
            completion: .familySpaceCreated(name: "The Carter Family")
        )

        let coordinator = OnboardingCoordinator(completionStore: store)

        #expect(coordinator.step == .complete)
        #expect(coordinator.completion == .familySpaceCreated(name: "The Carter Family"))
    }

    @Test("The educational sequence advances in the approved order")
    func advancesThroughEducation() {
        let coordinator = OnboardingCoordinator(
            completionStore: InMemoryOnboardingCompletionStore()
        )

        coordinator.getStarted()
        #expect(coordinator.step == .howItWorks)

        coordinator.continueFromHowItWorks()
        #expect(coordinator.step == .privacy)

        coordinator.setUpMySpace()
        #expect(coordinator.step == .familySpaceChoice)
    }

    @Test("Back returns through the actual navigation history")
    func backUsesHistory() {
        let coordinator = OnboardingCoordinator(
            completionStore: InMemoryOnboardingCompletionStore()
        )

        coordinator.getStarted()
        coordinator.continueFromHowItWorks()
        coordinator.goBack()
        #expect(coordinator.step == .howItWorks)

        coordinator.goBack()
        #expect(coordinator.step == .welcome)
        #expect(coordinator.canGoBack == false)
    }

    @Test("Invite entry from Welcome returns directly to Welcome")
    func inviteShortcutPreservesHistory() {
        let coordinator = OnboardingCoordinator(
            completionStore: InMemoryOnboardingCompletionStore()
        )

        coordinator.openInvite()
        #expect(coordinator.step == .joinFamilySpace)

        coordinator.goBack()
        #expect(coordinator.step == .welcome)
    }

    @Test("Create and join routes start from Family Space choice")
    func familyChoiceRoutes() {
        let coordinator = OnboardingCoordinator(
            completionStore: InMemoryOnboardingCompletionStore()
        )

        coordinator.getStarted()
        coordinator.continueFromHowItWorks()
        coordinator.setUpMySpace()

        coordinator.openCreateSpace()
        #expect(coordinator.step == .createFamilySpace)
        coordinator.goBack()
        #expect(coordinator.step == .familySpaceChoice)

        coordinator.openJoinSpace()
        #expect(coordinator.step == .joinFamilySpace)
    }
}

@MainActor
struct FamilySpaceNameValidatorTests {
    @Test("Names are trimmed before validation")
    func trimsNames() {
        let result = FamilySpaceNameValidator.validate("  The Carter Family  ")

        #expect(result == .valid("The Carter Family"))
    }

    @Test("Blank names are rejected")
    func rejectsBlankNames() {
        #expect(FamilySpaceNameValidator.validate("   ") == .invalid(.required))
    }

    @Test("Forty visible characters are accepted")
    func acceptsMaximumLength() {
        let name = String(repeating: "A", count: 40)

        #expect(FamilySpaceNameValidator.validate(name) == .valid(name))
    }

    @Test("More than forty visible characters are rejected")
    func rejectsOverMaximumLength() {
        let name = String(repeating: "A", count: 41)

        #expect(FamilySpaceNameValidator.validate(name) == .invalid(.tooLong(maximum: 40)))
    }
}

@MainActor
struct InviteCodeTests {
    @Test("Invite codes normalize case, spaces and separators")
    func normalizesPastedCode() {
        #expect(InviteCode(rawValue: " e-c h o 2 6 ")?.value == "ECHO26")
    }

    @Test("Invite codes require six letters or digits")
    func validatesLengthAndCharacters() {
        #expect(InviteCode(rawValue: "ECHO2") == nil)
        #expect(InviteCode(rawValue: "ECHO267") == nil)
        #expect(InviteCode(rawValue: "ECH@26") == nil)
        #expect(InviteCode(rawValue: "ÉCHO26") == nil)
    }

    @Test("The local demo invitation returns truthful preview metadata")
    func previewsKnownInvitation() {
        let preview = LocalInvitationValidator.preview(for: " e-c h o 2 6 ")

        #expect(preview?.code.value == "ECHO26")
        #expect(preview?.familyName == "The Carter Family")
        #expect(preview?.memberCount == 4)
        #expect(preview?.skillCount == 18)
        #expect(preview?.organizerName == "Emma")
        #expect(LocalInvitationValidator.preview(for: "ABC123") == nil)
    }
}

@MainActor
struct OnboardingModelTests {
    @Test("Completion copy and Family Space names match each result")
    func completionPresentation() {
        #expect(OnboardingCompletion.localOnly.title == "Your private library is ready.")
        #expect(OnboardingCompletion.localOnly.spaceName == nil)

        let created = OnboardingCompletion.familySpaceCreated(name: "Carter Makers")
        #expect(created.title == "Your Family Space is ready.")
        #expect(created.spaceName == "Carter Makers")

        let joined = OnboardingCompletion.familySpaceJoined(name: "The Carter Family")
        #expect(joined.title == "You're part of the family.")
        #expect(joined.spaceName == "The Carter Family")
    }

    @Test("Validation errors expose clear English guidance")
    func validationMessages() {
        #expect(FamilySpaceNameError.required.message == "Enter a name for your Family Space.")
        #expect(
            FamilySpaceNameError.tooLong(maximum: 40).message
                == "Keep the name to 40 characters or fewer."
        )
        #expect(
            OnboardingError.invalidFamilySpaceName(.required).errorDescription
                == "Enter a name for your Family Space."
        )
    }
}

@MainActor
struct OnboardingPersistenceTests {
    @Test("UserDefaults storage round-trips and clears completion")
    func roundTripsCompletion() throws {
        let suiteName = "CraftkinTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsOnboardingCompletionStore(
            defaults: defaults,
            key: "completion"
        )

        #expect(store.completion == nil)
        store.completion = .familySpaceJoined(name: "The Carter Family")
        #expect(store.completion == .familySpaceJoined(name: "The Carter Family"))

        store.reset()
        #expect(store.completion == nil)
    }

    @Test("Corrupt persisted data is treated as no completion")
    func ignoresCorruptData() throws {
        let suiteName = "CraftkinTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: "completion")

        let store = UserDefaultsOnboardingCompletionStore(
            defaults: defaults,
            key: "completion"
        )

        #expect(store.completion == nil)
        store.completion = nil
        #expect(defaults.data(forKey: "completion") == nil)
    }
}

@MainActor
struct OnboardingCompletionTests {
    @Test("Creating a Family Space stores normalized completion")
    func createCompletion() throws {
        let store = InMemoryOnboardingCompletionStore()
        let coordinator = OnboardingCoordinator(completionStore: store)

        try coordinator.completeCreatedSpace(named: "  The Carter Family ")

        #expect(store.completion == .familySpaceCreated(name: "The Carter Family"))
        #expect(coordinator.step == .complete)
    }

    @Test("Local setup stores local-only completion")
    func localCompletion() {
        let store = InMemoryOnboardingCompletionStore()
        let coordinator = OnboardingCoordinator(completionStore: store)

        coordinator.setUpLater()

        #expect(store.completion == .localOnly)
        #expect(coordinator.step == .complete)
    }

    @Test("Joining stores validated invitation metadata")
    func joinCompletion() throws {
        let store = InMemoryOnboardingCompletionStore()
        let coordinator = OnboardingCoordinator(completionStore: store)
        let invitation = InvitationPreview(
            code: InviteCode(rawValue: "ECHO26")!,
            familyName: "The Carter Family",
            memberCount: 4,
            skillCount: 18,
            organizerName: "Emma"
        )

        try coordinator.completeJoinedSpace(invitation)

        #expect(store.completion == .familySpaceJoined(name: "The Carter Family"))
        #expect(coordinator.step == .complete)
    }
}
