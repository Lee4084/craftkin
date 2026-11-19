import UIKit
import SwiftUI

@main
@MainActor
final class CraftkinApp: UIResponder, UIApplicationDelegate {
    private var requestedInitialScene = false

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationCenter.default.addObserver(self, selector: #selector(sceneConnected(_:)),
                                               name: UIScene.willConnectNotification, object: nil)

        DispatchQueue.main.async { [weak self, weak application] in
            guard let self, let application else { return }
            self.recoverSceneConnection(in: application.connectedScenes) {
                application.requestSceneSessionActivation(nil, userActivity: nil, options: nil, errorHandler: nil)
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
        guard !windows.isEmpty else {
            guard !requestedInitialScene else { return }
            requestedInitialScene = true
            requestScene()
            return
        }
        for scene in windows {
            if let delegate = scene.delegate as? CraftkinSceneDelegate {
                delegate.connectWindow(in: scene)
            } else {
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
        return configuration
    }
}

@MainActor
final class CraftkinSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        connectWindow(in: scene)
    }

    func connectWindow(in scene: UIWindowScene) {
        guard window == nil else { return }
        let window = scene.windows.first(where: { $0.isKeyWindow && $0.windowLevel == .normal })
            ?? UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.backgroundColor = .systemBackground
        self.window = window
        window.rootViewController = UIHostingController(rootView: AppEntryView())
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        LegalConsentHandler.shared.legalConsent4()
        window = nil
    }

    func sceneWillResignActive(_ scene: UIScene) { LegalConsentHandler.shared.legalConsent5(false) }
    func sceneDidEnterBackground(_ scene: UIScene) { LegalConsentHandler.shared.legalConsent5(false) }
    func sceneDidBecomeActive(_ scene: UIScene) { LegalConsentHandler.shared.legalConsent5(true) }
}
