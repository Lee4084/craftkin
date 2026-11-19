import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator: OnboardingCoordinator
    @State private var showsLibrary: Bool
    private let isCloudAvailable: Bool
    private let libraryState: LibraryContentState

    init(openLibrary: Bool = false) {
        let store = UserDefaultsOnboardingCompletionStore()

        _coordinator = StateObject(
            wrappedValue: OnboardingCoordinator(completionStore: store)
        )
        _showsLibrary = State(
            initialValue: openLibrary
        )
        libraryState = .populated
        isCloudAvailable = true
    }

    var body: some View {
        Group {
            if showsLibrary {
                LibraryRootView(
                    repository: LocalSampleSkillRepository(state: libraryState),
                    initialFamilyName: coordinator.completion?.spaceName,
                    onResetApp: { coordinator.restartSetup(); showsLibrary = false }
                )
            } else {
                OnboardingRootView(
                    coordinator: coordinator,
                    isCloudAvailable: isCloudAvailable,
                    onContinueToLibrary: { showsLibrary = true }
                )
            }
        }
        .environment(\.localAppActions, LocalAppActions(signOut: { showsLibrary = false }))
        .preferredColorScheme(.light)
    }

}
