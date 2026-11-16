import UIKit
import SwiftUI
import Combine

struct AppRootActions {
    let login: () -> Void
    let signOut: () -> Void
    var continueNative: (() -> Void)? = nil
}

private struct AppRootActionsKey: EnvironmentKey {
    static let defaultValue: AppRootActions? = nil
}

extension EnvironmentValues {
    var appRootActions: AppRootActions? {
        get { self[AppRootActionsKey.self] }
        set { self[AppRootActionsKey.self] = newValue }
    }
}

@MainActor
final class AppRootCoordinator {
    typealias NativeFactory = (Bool, AppRootActions) -> UIViewController
    typealias WebFactory = (WebPreparedSession, AppRootActions) -> UIViewController

    private weak var window: UIWindow?
    private let startup: WebIntegrationCoordinator
    private let resume: any AppNativeResumeStoring
    private let readIdentity: () throws -> String?
    private var isStartupEntry = false
    private let hasCompletedSetup: () -> Bool
    private let makeNative: NativeFactory
    private let makeWeb: WebFactory
    private var observation: AnyCancellable?
    private var returnRoot: UIViewController?
    private var nativeRoot: UIViewController?

    init(window: UIWindow, startup: WebIntegrationCoordinator? = nil,
         store: (any AppRootDestinationStoring)? = nil,
         resume: (any AppNativeResumeStoring)? = nil, readIdentity: (() throws -> String?)? = nil,
         hasCompletedSetup: @escaping () -> Bool = { UserDefaultsOnboardingCompletionStore().completion != nil },
         makeNative: NativeFactory? = nil, makeWeb: WebFactory? = nil) {
        self.window = window
        self.startup = startup ?? WebIntegrationAssembly.coordinator()
        // Legacy assignments remain unused; only an accepted H5 continuation enables native resume.
        self.resume = resume ?? UserDefaultsAppNativeResumeStore()
        self.readIdentity = readIdentity ?? { try WebActivityIdentityStore().read() }
        self.hasCompletedSetup = hasCompletedSetup
        self.makeNative = makeNative ?? { openLibrary, actions in
            UIHostingController(rootView: ContentView(openLibrary: openLibrary, rootActions: actions))
        }
        self.makeWeb = makeWeb ?? { session, actions in
            WebContainer.makeNavigationController(session: session, onClose: actions.signOut,
                onContinue: actions.continueNative)
        }
        observation = self.startup.$state.sink { [weak self] state in self?.handle(state) }
    }

    private var actions: AppRootActions {
        AppRootActions(login: { [weak self] in self?.startLogin() },
            signOut: { [weak self] in self?.signOut() },
            continueNative: { [weak self] in self?.continueNative() })
    }

    func start(arguments: [String] = ProcessInfo.processInfo.arguments) {
        #if DEBUG
        if arguments.contains("-uiTesting") {
            if arguments.contains("-resetOnboarding") { UserDefaultsOnboardingCompletionStore().reset() }
            if arguments.contains("-openLibrary") { replaceRoot(makeNative(true, actions)); return }
            startLogin(isStartup: true); return
        }
        #endif
        if let identity = try? readIdentity(), WebActivityIdentityStore.isValid(identity), resume.identity == identity {
            #if DEBUG
            print("[H5-Route] resumed_native")
            #endif
            continueNative()
            return
        }
        startLogin(isStartup: true)
    }

    func startLogin(isStartup: Bool = false) {
        guard startup.state != .connecting else { return }
        isStartupEntry = isStartup
        resume.identity = nil
        returnRoot = nativeRoot
        replaceRoot(UIHostingController(rootView: WebIntegrationView(coordinator: startup,
            onClose: { [weak self] in self?.signOut() }, onRetry: { [weak self] in guard let self else { return }; self.startLogin(isStartup: self.isStartupEntry) })))
        startup.start()
    }

    func signOut() {
        startup.cancel()
        showNative()
    }

    private func continueNative() {
        if let identity = try? readIdentity(), WebActivityIdentityStore.isValid(identity) { resume.identity = identity }
        #if DEBUG
        print("[H5-Route] selected_native")
        #endif
        startup.cancel()
        returnRoot = nil
        let native = makeNative(hasCompletedSetup(), actions)
        nativeRoot = native
        replaceRoot(native)
    }

    private func showNative() {
        startup.cancel()
        if let previous = returnRoot {
            returnRoot = nil
            replaceRoot(previous)
        } else {
            let native = makeNative(hasCompletedSetup(), actions)
            nativeRoot = native
            replaceRoot(native)
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
        startup.cancel()
        stopWebPages()
        returnRoot = nil
    }

    private func handle(_ state: WebIntegrationCoordinator.State) {
        guard window != nil else { return }
        if case .ready = state, let prepared = startup.prepared {
            var destination = prepared
            if isStartupEntry, prepared.isActivityEntry,
               var parts = URLComponents(url: prepared.entry, resolvingAgainstBaseURL: false) {
                var items = parts.queryItems ?? []
                items.removeAll { $0.name == "native" }
                parts.queryItems = items + [URLQueryItem(name: "native", value: "1")]
                if let url = parts.url {
                    destination = WebPreparedSession(entry: url, session: prepared.session, services: prepared.services,
                        environment: prepared.environment, isActivityEntry: prepared.isActivityEntry)
                }
            }
            replaceRoot(makeWeb(destination, actions))
        }
    }

    private func stopWebPages() {
        guard let navigation = window?.rootViewController as? UINavigationController else { return }
        for case let page as WebPageController in navigation.viewControllers { page.stop() }
    }

    private func replaceRoot(_ controller: UIViewController) {
        guard let window else { return }
        stopWebPages()
        window.rootViewController?.dismiss(animated: false)
        controller.overrideUserInterfaceStyle = .light
        window.rootViewController = controller
    }
}
