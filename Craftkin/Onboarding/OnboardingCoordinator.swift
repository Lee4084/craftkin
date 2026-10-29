import Combine
import Foundation

@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published private(set) var step: OnboardingStep
    @Published private(set) var completion: OnboardingCompletion?

    private var history: [OnboardingStep] = []
    private let completionStore: any OnboardingCompletionStoring

    init(completionStore: any OnboardingCompletionStoring) {
        self.completionStore = completionStore
        completion = completionStore.completion
        step = completionStore.completion == nil ? .welcome : .complete
    }

    var canGoBack: Bool { !history.isEmpty }

    func getStarted() { navigate(to: .howItWorks) }
    func continueFromHowItWorks() { navigate(to: .privacy) }
    func setUpMySpace() { navigate(to: .familySpaceChoice) }
    func openCreateSpace() { navigate(to: .createFamilySpace) }
    func openJoinSpace() { navigate(to: .joinFamilySpace) }
    func openInvite() { navigate(to: .joinFamilySpace) }

    func goBack() {
        guard let previous = history.popLast() else { return }
        step = previous
    }

    func setUpLater() {
        finish(with: .localOnly)
    }

    func restartSetup() {
        completionStore.completion = nil
        completion = nil
        history = []
        step = .welcome
    }

    func completeCreatedSpace(named rawName: String) throws {
        switch FamilySpaceNameValidator.validate(rawName) {
        case let .valid(name):
            finish(with: .familySpaceCreated(name: name))
        case let .invalid(error):
            throw OnboardingError.invalidFamilySpaceName(error)
        }
    }

    func completeJoinedSpace(_ invitation: InvitationPreview) throws {
        finish(with: .familySpaceJoined(name: invitation.familyName))
    }

    private func navigate(to nextStep: OnboardingStep) {
        history.append(step)
        step = nextStep
    }

    private func finish(with result: OnboardingCompletion) {
        completionStore.completion = result
        completion = result
        history.removeAll()
        step = .complete
    }
}

