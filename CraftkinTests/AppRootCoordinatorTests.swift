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

    func testEveryLaunchLoadsH5WithoutReadingLegacyAssignment() async throws {
        for destination in [AppRootDestination.signedOut, .native, .web] {
            let store = RootMemoryStore(destination)
            let service = RootResultService(result: try prepared())
            let startup = WebIntegrationCoordinator { service }
            let window = UIWindow(frame: UIScreen.main.bounds)
            let web = UINavigationController(rootViewController: UIViewController())
            var nativeBuilds = 0
            let coordinator = AppRootCoordinator(window: window, startup: startup, store: store, resume: RootNativeResumeMemory(), readIdentity: { nil },
                hasCompletedSetup: { true }, makeNative: { _, _ in nativeBuilds += 1; return UIViewController() },
                makeWeb: { _, _ in web })
            coordinator.start(arguments: [])
            for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
            XCTAssertTrue(window.rootViewController === web)
            XCTAssertEqual(service.calls, 1)
            XCTAssertEqual(nativeBuilds, 0)
            XCTAssertEqual(store.destination, destination)
            coordinator.stop()
        }
    }

    func testCloseAndContinueReturnToNativeAndLoginReopensH5() async throws {
        let startup = WebIntegrationCoordinator { RootResultService(result: try self.prepared()) }
        let window = UIWindow(frame: UIScreen.main.bounds)
        let native = UIViewController()
        let web = UINavigationController(rootViewController: UIViewController())
        var webActions: AppRootActions?
        var nativeActions: AppRootActions?
        let coordinator = AppRootCoordinator(window: window, startup: startup, resume: RootNativeResumeMemory(), readIdentity: { nil }, hasCompletedSetup: { true },
            makeNative: { _, actions in nativeActions = actions; return native },
            makeWeb: { _, actions in webActions = actions; return web })
        defer { coordinator.stop() }
        coordinator.start(arguments: [])
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        webActions?.continueNative?()
        XCTAssertTrue(window.rootViewController === native)
        nativeActions?.login()
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        XCTAssertTrue(window.rootViewController === web)
        webActions?.signOut()
        XCTAssertTrue(window.rootViewController === native)
    }

    func testFailedEntryCanCloseWithoutChangingLegacyDestination() async throws {
        let store = RootMemoryStore(.web)
        let service = RootResultService(result: nil, failure: WebIntegrationError.network)
        let startup = WebIntegrationCoordinator { service }
        let window = UIWindow(frame: UIScreen.main.bounds)
        let native = UIViewController()
        let coordinator = AppRootCoordinator(window: window, startup: startup, store: store, resume: RootNativeResumeMemory(), readIdentity: { nil },
            hasCompletedSetup: { false }, makeNative: { _, _ in native }, makeWeb: { _, _ in UIViewController() })
        defer { coordinator.stop() }
        coordinator.start(arguments: [])
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        let loading = try XCTUnwrap(window.rootViewController as? UIHostingController<WebIntegrationView>)
        loading.rootView.onClose()
        XCTAssertTrue(window.rootViewController === native)
        XCTAssertEqual(store.destination, .web)
    }

    func testContinueAfterSetupOpensLibraryInsteadOfRestoringCompletionLoop() async throws {
        var completed = false
        var openedLibrary: [Bool] = []
        var nativeActions: AppRootActions?
        var webActions: AppRootActions?
        let startup = WebIntegrationCoordinator { RootResultService(result: try self.prepared()) }
        let window = UIWindow(frame: UIScreen.main.bounds)
        let coordinator = AppRootCoordinator(window: window, startup: startup, resume: RootNativeResumeMemory(), readIdentity: { nil }, hasCompletedSetup: { completed },
            makeNative: { opensLibrary, actions in openedLibrary.append(opensLibrary); nativeActions = actions; return UIViewController() },
            makeWeb: { _, actions in webActions = actions; return UINavigationController(rootViewController: UIViewController()) })
        defer { coordinator.stop() }
        coordinator.start(arguments: [])
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        webActions?.signOut()
        XCTAssertEqual(openedLibrary, [false])
        completed = true
        nativeActions?.login()
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        webActions?.continueNative?()
        XCTAssertEqual(openedLibrary, [false, true])
    }

    func testAcceptedNativeContinuationRestoresNativeDirectlyAfterRelaunch() async throws {
        let defaults = UserDefaults(suiteName: "test.native.resume." + UUID().uuidString)!
        let firstStore = UserDefaultsAppNativeResumeStore(defaults: defaults)
        let identity = "11111111-1111-4111-8111-111111111111"
        let service = RootResultService(result: try prepared())
        let startup = WebIntegrationCoordinator { service }
        let window = UIWindow(frame: UIScreen.main.bounds)
        var callbacks: AppRootActions?
        let coordinator = AppRootCoordinator(window: window, startup: startup, resume: firstStore, readIdentity: { identity },
            hasCompletedSetup: { true }, makeNative: { _, _ in UIViewController() },
            makeWeb: { _, actions in callbacks = actions; return UIViewController() })
        coordinator.start(arguments: [])
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        callbacks?.continueNative?()
        XCTAssertEqual(firstStore.identity, identity)
        coordinator.stop()

        let nextService = RootResultService(result: try prepared())
        let nextStartup = WebIntegrationCoordinator { nextService }
        let nextWindow = UIWindow(frame: UIScreen.main.bounds)
        let native = UIViewController()
        let nextStore = UserDefaultsAppNativeResumeStore(defaults: defaults)
        let next = AppRootCoordinator(window: nextWindow, startup: nextStartup, resume: nextStore, readIdentity: { identity },
            hasCompletedSetup: { true }, makeNative: { _, _ in native }, makeWeb: { _, _ in XCTFail("H5 guide must not open"); return UIViewController() })
        next.start(arguments: [])
        XCTAssertTrue(nextWindow.rootViewController === native)
        XCTAssertEqual(nextService.calls, 0)
        next.stop()
        nextStore.identity = nil
    }

    func testNativeResumeIsBoundToCurrentIdentityAndManualLoginClearsIt() async throws {
        let identity = "11111111-1111-4111-8111-111111111111"
        let resume = RootNativeResumeMemory()
        resume.identity = "22222222-2222-4222-8222-222222222222"
        let service = RootResultService(result: try prepared())
        let startup = WebIntegrationCoordinator { service }
        let window = UIWindow(frame: UIScreen.main.bounds)
        var webActions: AppRootActions?
        var nativeActions: AppRootActions?
        let web = UIViewController()
        let coordinator = AppRootCoordinator(window: window, startup: startup, resume: resume, readIdentity: { identity },
            hasCompletedSetup: { true }, makeNative: { _, actions in nativeActions = actions; return UIViewController() },
            makeWeb: { _, actions in webActions = actions; return web })
        coordinator.start(arguments: [])
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        XCTAssertTrue(window.rootViewController === web)
        XCTAssertNil(resume.identity)
        webActions?.continueNative?()
        XCTAssertEqual(resume.identity, identity)
        nativeActions?.login()
        XCTAssertNil(resume.identity)
        for _ in 0..<100 where startup.state == .connecting { await Task.yield() }
        XCTAssertTrue(window.rootViewController === web)
        coordinator.stop()
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

private final class RootNativeResumeMemory: AppNativeResumeStoring {
    var identity: String?
}
