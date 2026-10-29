//
//  ContentView.swift
//  Craftkin
//
//  Created by mac on 2026/10/19.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator: OnboardingCoordinator
    @State private var showsLibrary: Bool
    private let rootActions: AppRootActions
    private let isCloudAvailable: Bool
    private let libraryState: LibraryFixtureState

    init(openLibrary: Bool = false, rootActions: AppRootActions) {
        self.rootActions = rootActions
        let arguments = ProcessInfo.processInfo.arguments
        let store = UserDefaultsOnboardingCompletionStore()

        let fixtureState = LibraryFixtureState.launchState(arguments: arguments)

        _coordinator = StateObject(
            wrappedValue: OnboardingCoordinator(completionStore: store)
        )
        _showsLibrary = State(
            initialValue: openLibrary
        )
        libraryState = fixtureState
        isCloudAvailable = Self.cloudAvailability(from: arguments)
    }

    var body: some View {
        Group {
            if showsLibrary {
                LibraryRootView(
                    repository: LocalSampleSkillRepository(state: libraryState),
                    initialFamilyName: coordinator.completion?.spaceName,
                    onResetApp: { coordinator.restartSetup(); showsLibrary = false; rootActions.signOut() }
                )
            } else {
                OnboardingRootView(
                    coordinator: coordinator,
                    isCloudAvailable: isCloudAvailable,
                    onContinueToLibrary: rootActions.login
                )
            }
        }
        .environment(\.appRootActions, rootActions)
        .preferredColorScheme(.light)
    }

    private static func cloudAvailability(from arguments: [String]) -> Bool {
        guard let flagIndex = arguments.firstIndex(of: "-icloudAvailable"),
              arguments.indices.contains(flagIndex + 1) else {
            return true
        }
        return arguments[flagIndex + 1] == "1"
    }
}

#Preview {
    ContentView(rootActions: AppRootActions(login: {}, signOut: {}))
}
