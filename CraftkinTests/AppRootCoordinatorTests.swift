#if canImport(UIKit)
import UIKit
import SwiftUI
import XCTest
@testable import Craftkin

@MainActor
final class AppRootCoordinatorTests: XCTestCase {
    func testMissingSceneRequestsActivationOnlyOnce() {
        let app = CraftkinApp()
        var requests = 0
        app.recoverSceneConnection(in: [], requestScene: { requests += 1 })
        app.recoverSceneConnection(in: [], requestScene: { requests += 1 })
        XCTAssertEqual(requests, 1)
    }

    func testApplicationExportsBothUIKitLaunchSelectors() {
        let app = CraftkinApp()
        XCTAssertTrue(app.responds(to: #selector(UIApplicationDelegate.application(_:didFinishLaunchingWithOptions:))))
        XCTAssertTrue(app.responds(to: #selector(UIApplicationDelegate.application(_:configurationForConnecting:options:))))
    }

    func testAppRegistersTheRootWindowSceneDelegate() throws {
        let bundle = Bundle(for: CraftkinApp.self)
        let manifest = try XCTUnwrap(bundle.infoDictionary?["UIApplicationSceneManifest"] as? [String: Any])
        let configurations = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let application = try XCTUnwrap(configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]])
        let configuration = try XCTUnwrap(application.first)
        XCTAssertEqual(configuration["UISceneConfigurationName"] as? String, "Default Configuration")
        let delegate = try XCTUnwrap(configuration["UISceneDelegateClassName"] as? String)
        XCTAssertTrue(NSClassFromString(delegate) === CraftkinSceneDelegate.self)
    }

    func testCancelFailedLoginRestoresTheExistingNativeRoot() async throws {
        let store = RootMemoryStore(.native)
        let service = RootResultService(result: nil, failure: WebIntegrationError.network)
        let startup = WebIntegrationCoordinator { service }
        let window = UIWindow(frame: UIScreen.main.bounds)
        let native = UIViewController()
        let coordinator = AppRootCoordinator(window: window, startup: startup, store: store,
            hasCompletedSetup: { true }, makeNative: { _, _ in native }, makeWeb: { _, _ in UIViewController() })
        defer { coordinator.stop() }
        coordinator.start(arguments: [])
        coordinator.startLogin()
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        let loading = try XCTUnwrap(window.rootViewController as? UIHostingController<WebIntegrationView>)
        loading.rootView.onClose()
        XCTAssertTrue(window.rootViewController === native)
        XCTAssertEqual(store.destination, .native)
        XCTAssertNil(native.presentedViewController)
    }

    func testLoginReplacesRootAndColdStartDoesNotBuildNativeHome() async throws {
        let store = RootMemoryStore(.signedOut)
        let service = RootResultService(result: try prepared())
        let startup = WebIntegrationCoordinator { service }
        let window = UIWindow(frame: UIScreen.main.bounds)
        let native = UIViewController()
        let web = UINavigationController(rootViewController: UIViewController())
        var actions: AppRootActions?
        let coordinator = AppRootCoordinator(window: window, startup: startup, store: store,
            hasCompletedSetup: { true }, makeNative: { _, value in actions = value; return native },
            makeWeb: { _, _ in web })
        coordinator.start(arguments: [])
        XCTAssertTrue(window.rootViewController === native)
        actions?.login()
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        XCTAssertTrue(window.rootViewController === web)
        XCTAssertNil(web.presentedViewController)
        XCTAssertEqual(store.destination, .web)
        coordinator.stop()
        XCTAssertEqual(store.destination, .web)

        let nextWindow = UIWindow(frame: UIScreen.main.bounds)
        let nextService = RootResultService(result: try prepared())
        let nextStartup = WebIntegrationCoordinator { nextService }
        let nextWeb = UINavigationController(rootViewController: UIViewController())
        var nativeBuilds = 0
        let next = AppRootCoordinator(window: nextWindow, startup: nextStartup, store: store,
            hasCompletedSetup: { true }, makeNative: { _, _ in nativeBuilds += 1; return UIViewController() },
            makeWeb: { _, _ in nextWeb })
        defer { next.stop() }
        next.start(arguments: [])
        XCTAssertEqual(nativeBuilds, 0)
        for _ in 0..<100 where nextStartup.state == .connecting { await Task.yield() }
        XCTAssertEqual(nextService.calls, 1)
        XCTAssertEqual(nativeBuilds, 0)
        XCTAssertTrue(nextWindow.rootViewController === nextWeb)
        XCTAssertNil(nextWeb.presentedViewController)
    }

    func testSignOutPreventsAutomaticWebRestoreDespiteSavedSetup() async throws {
        let store = RootMemoryStore(.web)
        let service = RootResultService(result: try prepared())
        let startup = WebIntegrationCoordinator { service }
        let window = UIWindow(frame: UIScreen.main.bounds)
        let login = UIViewController()
        let coordinator = AppRootCoordinator(window: window, startup: startup, store: store,
            hasCompletedSetup: { true }, makeNative: { opensLibrary, _ in
                XCTAssertFalse(opensLibrary)
                return login
            }, makeWeb: { _, _ in UIViewController() })
        defer { coordinator.stop() }
        coordinator.signOut()
        coordinator.start(arguments: [])
        XCTAssertEqual(store.destination, .signedOut)
        XCTAssertEqual(service.calls, 0)
        XCTAssertTrue(window.rootViewController === login)
    }

    func testFailureAndCancellationCannotMarkLoginSuccessful() async throws {
        let store = RootMemoryStore(.signedOut)
        let service = RootResultService(result: try prepared(), failure: WebIntegrationError.network)
        let startup = WebIntegrationCoordinator { service }
        let window = UIWindow(frame: UIScreen.main.bounds)
        let login = UIViewController()
        var webBuilds = 0
        let coordinator = AppRootCoordinator(window: window, startup: startup, store: store,
            hasCompletedSetup: { true }, makeNative: { _, _ in login },
            makeWeb: { _, _ in webBuilds += 1; return UIViewController() })
        defer { coordinator.stop() }
        coordinator.startLogin()
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        XCTAssertEqual(startup.state, .failed(.network))
        XCTAssertEqual(store.destination, .signedOut)
        XCTAssertEqual(webBuilds, 0)
        service.failure = nil
        coordinator.startLogin()
        coordinator.signOut()
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(store.destination, .signedOut)
        XCTAssertEqual(webBuilds, 0)
        XCTAssertTrue(window.rootViewController === login)
    }

    func testNativeStrategySelectsNativeRoot() async throws {
        let store = RootMemoryStore(.signedOut)
        let service = RootResultService(result: nil)
        let startup = WebIntegrationCoordinator { service }
        let window = UIWindow(frame: UIScreen.main.bounds)
        let native = UIViewController()
        let coordinator = AppRootCoordinator(window: window, startup: startup, store: store,
            hasCompletedSetup: { true }, makeNative: { opensLibrary, _ in
                XCTAssertTrue(opensLibrary)
                return native
            }, makeWeb: { _, _ in XCTFail("Unexpected web root"); return UIViewController() })
        defer { coordinator.stop() }
        coordinator.startLogin()
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        XCTAssertTrue(window.rootViewController === native)
        XCTAssertEqual(store.destination, .native)
    }

    private func prepared() throws -> WebPreparedSession {
        let environment = try WebIntegrationTests.environment()
        let origin = URL(string: "https://web.example.test")!
        return WebPreparedSession(entry: URL(string: "https://web.example.test/h5_web/app/")!,
            session: WebSession(userID: "synthetic-user", credential: "synthetic-session"),
            services: WebRemoteServices(web: origin, messaging: nil, events: nil, contactID: nil), environment: environment)
    }
}

private final class RootMemoryStore: AppRootDestinationStoring {
    var destination: AppRootDestination?
    init(_ destination: AppRootDestination?) { self.destination = destination }
}

@MainActor
private final class RootResultService: WebSessionPreparing {
    let result: WebPreparedSession?
    var failure: Error?
    private(set) var calls = 0
    init(result: WebPreparedSession?, failure: Error? = nil) { self.result = result; self.failure = failure }
    func prepare() async throws -> WebPreparedSession? {
        calls += 1
        if let failure { throw failure }
        return result
    }
}
#endif
