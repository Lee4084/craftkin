import UIKit

@main
@MainActor
final class CraftkinApp: UIResponder, UIApplicationDelegate {
    private var requestedInitialScene = false

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if DEBUG
        print("[H5-Startup] application launched")
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") { UIView.setAnimationsEnabled(false) }
        #endif
        NotificationCenter.default.addObserver(self, selector: #selector(sceneConnected(_:)),
                                               name: UIScene.willConnectNotification, object: nil)
        // Upgraded installs can restore a scene created by the previous SwiftUI lifecycle.
        // Wait until launch returns so UIKit can finish its normal connection first.
        DispatchQueue.main.async { [weak self, weak application] in
            guard let self, let application else { return }
            self.recoverSceneConnection(in: application.connectedScenes) {
                application.requestSceneSessionActivation(nil, userActivity: nil, options: nil) { error in
                    #if DEBUG
                    let error = error as NSError
                    print("[H5-Startup] scene activation failed domain=\(error.domain) code=\(error.code)")
                    #endif
                }
            }
        }
        return true
    }

    @objc private func sceneConnected(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene,
              scene.session.role == .windowApplication else { return }
        DispatchQueue.main.async { [weak self, weak scene] in
            guard let self, let scene else { return }
            self.recoverSceneConnection(in: [scene], requestScene: {})
        }
    }

    func recoverSceneConnection(in scenes: Set<UIScene>, requestScene: () -> Void) {
        let windows = scenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication }
        #if DEBUG
        print("[H5-Startup] scene check connected=\(scenes.count) main=\(windows.count)")
        #endif
        guard !windows.isEmpty else {
            guard !requestedInitialScene else { return }
            requestedInitialScene = true
            #if DEBUG
            print("[H5-Startup] requesting initial window scene")
            #endif
            requestScene()
            return
        }
        for scene in windows {
            if let delegate = scene.delegate as? CraftkinSceneDelegate {
                delegate.connectWindow(in: scene)
            } else {
                #if DEBUG
                print("[H5-Startup] restoring window ownership")
                #endif
                let delegate = CraftkinSceneDelegate()
                scene.delegate = delegate
                delegate.connectWindow(in: scene)
            }
        }
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.sceneClass = UIWindowScene.self
        configuration.delegateClass = CraftkinSceneDelegate.self
        #if DEBUG
        print("[H5-Startup] window scene configured")
        #endif
        return configuration
    }
}

@MainActor
final class CraftkinSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootCoordinator: AppRootCoordinator?
    private var screenPrivacy: ScreenPrivacyController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        connectWindow(in: scene)
    }

    func connectWindow(in scene: UIWindowScene) {
        guard window == nil else { return }
        #if DEBUG
        print("[H5-Startup] connecting root window")
        #endif
        let window = scene.windows.first(where: { $0.isKeyWindow && $0.windowLevel == .normal })
            ?? UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.backgroundColor = .systemBackground
        self.window = window
        screenPrivacy = ScreenPrivacyController(scene: scene, contentWindow: window)
        let coordinator = AppRootCoordinator(window: window)
        rootCoordinator = coordinator
        coordinator.start()
        window.makeKeyAndVisible()
        #if DEBUG
        print("[H5-Startup] window visible width=\(window.bounds.width) height=\(window.bounds.height) root=\(window.rootViewController != nil)")
        #endif
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        screenPrivacy?.stop()
        screenPrivacy = nil
        rootCoordinator?.stop()
        rootCoordinator = nil
        window = nil
    }

    func sceneWillResignActive(_ scene: UIScene) { screenPrivacy?.setActive(false) }
    func sceneDidEnterBackground(_ scene: UIScene) { screenPrivacy?.setActive(false) }
    func sceneDidBecomeActive(_ scene: UIScene) { screenPrivacy?.setActive(true) }
}
