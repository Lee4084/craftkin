import UIKit
import SwiftUI
import Combine

struct AppRootActions {
    let login: () -> Void
    let signOut: () -> Void
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
    private let store: any AppRootDestinationStoring
    private let hasCompletedSetup: () -> Bool
    private let makeNative: NativeFactory
    private let makeWeb: WebFactory
    private var observation: AnyCancellable?
    private enum Screen { case native, connecting, web }
    private var screen: Screen = .native
    private var returnRoot: UIViewController?
    private var returnDestination: AppRootDestination?

    init(window: UIWindow, startup: WebIntegrationCoordinator? = nil,
         store: any AppRootDestinationStoring = UserDefaultsAppRootDestinationStore(),
         hasCompletedSetup: @escaping () -> Bool = { UserDefaultsOnboardingCompletionStore().completion != nil },
         makeNative: NativeFactory? = nil, makeWeb: WebFactory? = nil) {
        self.window = window
        self.startup = startup ?? WebIntegrationAssembly.coordinator()
        self.store = store
        self.hasCompletedSetup = hasCompletedSetup
        self.makeNative = makeNative ?? { openLibrary, actions in
            UIHostingController(rootView: ContentView(openLibrary: openLibrary, rootActions: actions))
        }
        self.makeWeb = makeWeb ?? { session, actions in
            WebContainer.makeNavigationController(session: session, onClose: actions.signOut)
        }
        observation = self.startup.$state.sink { [weak self] state in self?.handle(state) }
    }

    private var actions: AppRootActions {
        AppRootActions(login: { [weak self] in self?.startLogin() }, signOut: { [weak self] in self?.signOut() })
    }

    func start(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let resetsSetup = arguments.contains("-resetOnboarding")
        if resetsSetup {
            store.destination = .signedOut
            UserDefaultsOnboardingCompletionStore().reset()
        }
        let route = AppLaunchRoute.resolve(saved: store.destination,
            hasCompletedSetup: !resetsSetup && hasCompletedSetup(), forceNative: arguments.contains("-openLibrary"))
        switch route {
        case .login:
            if store.destination == nil { store.destination = .signedOut }
            replaceRoot(makeNative(false, actions))
        case .native: replaceRoot(makeNative(true, actions))
        case .authenticateWeb: startLogin()
        }
    }

    func startLogin() {
        guard startup.state != .connecting else { return }
        if screen != .connecting {
            returnRoot = screen == .native ? window?.rootViewController : nil
            returnDestination = store.destination
        }
        screen = .connecting
        let loading = UIHostingController(rootView: WebIntegrationView(coordinator: startup,
            onClose: { [weak self] in self?.cancelLogin() }, onRetry: { [weak self] in self?.startLogin() }))
        replaceRoot(loading)
        startup.start()
    }

    func signOut() {
        startup.cancel()
        screen = .native
        returnRoot = nil
        store.destination = .signedOut
        replaceRoot(makeNative(false, actions))
    }

    private func cancelLogin() {
        startup.cancel()
        guard let previous = returnRoot else { signOut(); return }
        returnRoot = nil
        screen = .native
        store.destination = returnDestination
        replaceRoot(previous)
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
        switch state {
        case .ready:
            guard let prepared = startup.prepared else { return }
            screen = .web
            returnRoot = nil
            replaceRoot(makeWeb(prepared, actions))
            store.destination = .web
        case .native:
            screen = .native
            returnRoot = nil
            replaceRoot(makeNative(true, actions))
            store.destination = .native
        default: break
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
        #if DEBUG
        print("[H5-Startup] root installed type=\(String(describing: type(of: controller)))")
        #endif
    }
}
