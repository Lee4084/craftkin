import SwiftUI

struct LocalAppActions { let signOut: () -> Void }
private struct LocalAppActionsKey: EnvironmentKey { static let defaultValue: LocalAppActions? = nil }
extension EnvironmentValues {
    var localAppActions: LocalAppActions? {
        get { self[LocalAppActionsKey.self] }
        set { self[LocalAppActionsKey.self] = newValue }
    }
}

struct AppEntryView: View {
    private let store: LegalConsentStore
    @State private var accepted: Bool

    init() {
        let store = LegalConsentStore()
        self.store = store
        _accepted = State(initialValue: store.hasAccepted)
    }

    var body: some View {
        if accepted {
            ContentView(openLibrary: opensLibrary)
        } else {
            LegalConsentView { store.accept(); accepted = true }
        }
    }

    private var opensLibrary: Bool {
        return UserDefaultsOnboardingCompletionStore().completion != nil
    }
}
