import Foundation
import XCTest
@testable import Craftkin

@MainActor
final class WebIntegrationTests: XCTestCase {
    func testRecordingHidesContentAndStoppingRestoresIt() {
        var state = ScreenPrivacyState()
        state.update(active: true, captured: true)
        XCTAssertEqual(state.cover, .recording)
        state.update(active: true, captured: false)
        XCTAssertNil(state.cover)
    }

    func testInactiveCoverStaysUntilForegroundAndCaptureChecksFinish() {
        var state = ScreenPrivacyState()
        state.update(active: false, captured: false)
        XCTAssertEqual(state.cover, .inactive)
        state.update(active: false, captured: true)
        XCTAssertEqual(state.cover, .inactive)
        state.update(active: true, captured: true)
        XCTAssertEqual(state.cover, .recording)
        state.update(active: true, captured: false)
        XCTAssertNil(state.cover)
    }

    func testScreenshotNoticeCannotDismissRecordingCover() {
        var state = ScreenPrivacyState()
        state.update(active: true, captured: false)
        state.screenshotTaken()
        XCTAssertEqual(state.cover, .screenshot)
        state.update(active: true, captured: true)
        state.dismissScreenshot()
        XCTAssertEqual(state.cover, .recording)
    }

    func testScreenshotNoticeDismissesAndDoesNotReappearAfterBackgrounding() {
        var state = ScreenPrivacyState()
        state.update(active: true, captured: false)
        state.screenshotTaken()
        state.dismissScreenshot()
        XCTAssertNil(state.cover)
        state.screenshotTaken()
        state.update(active: false, captured: false)
        state.update(active: true, captured: false)
        XCTAssertNil(state.cover)
        state.update(active: false, captured: false)
        state.screenshotTaken()
        state.update(active: true, captured: false)
        XCTAssertNil(state.cover)
    }

    func testFinishedDocumentIsNotReadyUntilItHasVisibleContent() async throws {
        var state = WebPageReadiness()
        state.begin()
        XCTAssertEqual(state.phase, .loading)
        XCTAssertEqual(state.timeoutReason, .network)
        state.finishDocument()
        XCTAssertEqual(state.phase, .rendering)
        XCTAssertFalse(state.observeContent(visible: false))
        XCTAssertEqual(state.timeoutReason, .emptyPage)
        XCTAssertTrue(state.observeContent(visible: true))
        XCTAssertEqual(state.phase, .ready)
    }

    func testPageFailureAndCloseCannotBeReplacedByLateContentChecks() async throws {
        var state = WebPageReadiness()
        state.begin()
        state.finishDocument()
        state.fail()
        XCTAssertFalse(state.observeContent(visible: true))
        XCTAssertEqual(state.phase, .failed)
        state.begin()
        state.finishDocument()
        state.cancel()
        state.finishDocument()
        XCTAssertFalse(state.observeContent(visible: true))
        XCTAssertEqual(state.phase, .idle)
        state.begin()
        state.finishDocument()
        XCTAssertTrue(state.observeContent(visible: true))
    }

    func testRequestTraceIncludesIDsAndExcludesURLSecrets() async throws {
        let id = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let trace = WebRequestTrace(stage: .page,
            url: URL(string: "https://name:secret@web.example.test/private?token=secret#/route")!,
            installationID: "synthetic-install", userID: "synthetic-user", id: id)
        let failure = NSError(domain: NSURLErrorDomain, code: -1009,
            userInfo: [NSURLErrorFailingURLStringErrorKey: "https://web.example.test/?token=secret"])
        let line = trace.line(.failure, error: failure)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.dropFirst(WebRequestTrace.prefix.count).utf8)) as? [String: Any])
        XCTAssertEqual(object["request_id"] as? String, id.uuidString)
        XCTAssertEqual(object["device-id"] as? String, "synthetic-install")
        XCTAssertEqual(object["user_id"] as? String, "synthetic-user")
        XCTAssertEqual(object["origin"] as? String, "https://web.example.test")
        XCTAssertEqual(object["error"] as? String, "H5-5-U-1009")
        for forbidden in ["secret", "private", "route", "name:", "token="] { XCTAssertFalse(line.contains(forbidden)) }
        XCTAssertFalse(line.contains("\n"))
    }

    func testAPITracesConnectRequestsWithInstallationAndReturnedUserID() async throws {
        let environment = try Self.environment()
        let codec = WebCompatibilityCodec()
        let transport = try Self.transport(codec: codec, environment: environment)
        var lines: [String] = []
        let client = WebAPIClient(environment: environment, transport: transport, codec: codec,
            identity: Self.identity, traceOutput: { lines.append($0) })
        let configuration = try await WebConfigurationService(client: client).fetch()
        let session = try await WebIdentityService(client: client).establish(key: configuration.material)
        _ = try await WebServiceDirectory(client: client).fetch(key: configuration.material, session: session)
        XCTAssertEqual(lines.count, 6)
        let records = try lines.map { line in
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.dropFirst(WebRequestTrace.prefix.count).utf8)) as? [String: Any])
        }
        XCTAssertEqual(Set(records.compactMap { $0["request_id"] as? String }).count, 3)
        for record in records { XCTAssertEqual(record["device-id"] as? String, Self.identity.installation) }
        XCTAssertEqual(records[3]["user_id"] as? String, "synthetic-user")
        XCTAssertEqual(records[4]["user_id"] as? String, "synthetic-user")
        XCTAssertEqual(records[0]["request_id"] as? String, records[1]["request_id"] as? String)
        XCTAssertFalse(lines.joined().contains("synthetic-session"))
    }

    func testFrameSourceUsesCommittedDocumentAndMatchingSecurityOrigin() async throws {
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        let document = URL(string: "https://web.example.test/h5_web/app/#/page")!
        for port in [0, 443] {
            let source = WebFrameSource(mainFrame: true, scheme: "HTTPS", host: "WEB.EXAMPLE.TEST", port: port)
            let verified = try XCTUnwrap(source.trustedPageURL(document, policy: policy))
            XCTAssertEqual(verified, document)
            XCTAssertEqual(try WebBridgeParser(policy: policy).parse(URL(string: "go://i?t_pams=false")!, source: verified, mainFrame: source.mainFrame, availability: .loading), .history(false))
        }
    }

    func testMissingBlankForeignAndSubframeSourcesCannotGainBridgeAccess() async throws {
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        let document = URL(string: "https://web.example.test/h5_web/app/")!
        let trusted = WebFrameSource(mainFrame: true, scheme: "https", host: "web.example.test", port: 443)
        XCTAssertNil(trusted.trustedPageURL(nil, policy: policy))
        XCTAssertNil(trusted.trustedPageURL(URL(string: "about:blank")!, policy: policy))
        XCTAssertNil(trusted.trustedPageURL(URL(string: "https://web.example.test/private/")!, policy: policy))
        for source in [WebFrameSource(mainFrame: false, scheme: "https", host: "web.example.test", port: 443),
                       WebFrameSource(mainFrame: true, scheme: "", host: "", port: 0),
                       WebFrameSource(mainFrame: true, scheme: "https", host: "outside.example.test", port: 443),
                       WebFrameSource(mainFrame: true, scheme: "http", host: "web.example.test", port: 443),
                       WebFrameSource(mainFrame: true, scheme: "https", host: "web.example.test", port: 8443)] {
            XCTAssertNil(source.trustedPageURL(document, policy: policy))
        }
    }

    func testKeepAwakeDefersUntilActiveAndRestoresTheOriginalValue() async throws {
        var state = WebIdleTimerState()
        XCTAssertNil(state.request(true, active: false, currentValue: false))
        XCTAssertNil(state.activate(active: false, currentValue: false))
        XCTAssertEqual(state.activate(active: true, currentValue: false), true)
        XCTAssertEqual(state.request(true, active: true, currentValue: true), true)
        XCTAssertEqual(state.suspend(), false)
        XCTAssertEqual(state.activate(active: true, currentValue: false), true)
        XCTAssertEqual(state.end(), false)
        XCTAssertNil(state.activate(active: true, currentValue: false))
    }

    func testKeepAwakeOffCanCleanUpWhileInactiveWithoutOverwritingAnotherOwner() async throws {
        var state = WebIdleTimerState()
        XCTAssertEqual(state.request(true, active: true, currentValue: true), true)
        XCTAssertEqual(state.request(false, active: false, currentValue: true), true)
        XCTAssertNil(state.end())
        XCTAssertNil(state.request(true, active: false, currentValue: false))
        XCTAssertNil(state.request(false, active: false, currentValue: false))
        XCTAssertNil(state.activate(active: true, currentValue: false))
        XCTAssertNil(state.suspend())
    }

    func testHiddenPageKeepAwakeDoesNotRaiseUnsupportedOrAcquireALock() async throws {
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        let parser = WebBridgeParser(policy: policy)
        let source = URL(string: "https://web.example.test/h5_web/app/")!
        XCTAssertEqual(try parser.parse(URL(string: "go://g?t_pams=true")!, source: source, mainFrame: true, availability: .hidden), .ignored)
        XCTAssertEqual(try parser.parse(URL(string: "go://g?t_pams=false")!, source: source, mainFrame: true, availability: .hidden), .keepAwake(false))
        XCTAssertThrowsError(try parser.parse(URL(string: "go://g?t_pams=invalid")!, source: source, mainFrame: true, availability: .hidden))
        XCTAssertEqual(try parser.parseBrowser(URL(string: "go://g?t_pams=true")!, source: URL(string: "https://provider.example.test/checkout")!, mainFrame: true), .keepAwake(true))
    }

    func testColdLaunchSelectsWebAuthenticationWithoutOpeningNativeHome() async throws {
        XCTAssertEqual(AppLaunchRoute.resolve(saved: .web, hasCompletedSetup: true), .authenticateWeb)
        XCTAssertEqual(AppLaunchRoute.resolve(saved: .web, hasCompletedSetup: false), .authenticateWeb)
        XCTAssertEqual(AppLaunchRoute.resolve(saved: nil, hasCompletedSetup: true), .authenticateWeb)
        XCTAssertEqual(AppLaunchRoute.resolve(saved: .signedOut, hasCompletedSetup: true), .login)
        XCTAssertEqual(AppLaunchRoute.resolve(saved: nil, hasCompletedSetup: false), .login)
        XCTAssertEqual(AppLaunchRoute.resolve(saved: .native, hasCompletedSetup: true), .native)
        XCTAssertEqual(AppLaunchRoute.resolve(saved: .web, hasCompletedSetup: true, forceNative: true), .native)
    }

    func testRootDestinationPersistsAndLogoutDoesNotUseLegacySetupAsLogin() async throws {
        let name = "root-routing-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = UserDefaultsAppRootDestinationStore(defaults: defaults)
        XCTAssertNil(first.destination)
        first.destination = .web
        let nextLaunch = UserDefaultsAppRootDestinationStore(defaults: defaults)
        XCTAssertEqual(nextLaunch.destination, .web)
        nextLaunch.destination = .signedOut
        XCTAssertEqual(first.destination, .signedOut)
        XCTAssertEqual(AppLaunchRoute.resolve(saved: first.destination, hasCompletedSetup: true), .login)
        defaults.set(999, forKey: IntegrationConstants.Storage.rootDestination)
        XCTAssertNil(first.destination)
        first.destination = nil
        XCTAssertNil(defaults.object(forKey: IntegrationConstants.Storage.rootDestination))
    }

    func testProvidedAgreementsReachH5InTheirConfirmedRoles() async throws {
        var values = IntegrationConstants.testEnvironmentValues
        values[IntegrationConstants.Configuration.entryKey] = String(repeating: "e", count: 32)
        let environment = try WebEnvironment(values: values)
        let codec = WebCompatibilityCodec()
        let transport = try Self.transport(codec: codec, environment: environment)
        let directory: [String: Any] = ["code": 0, "data": ["isReviewPkg": false, "data": ["dr": [IntegrationConstants.Host.web, "", ""]]]]
        transport.responses[2] = try codec.encode(JSONSerialization.data(withJSONObject: directory), key: String(repeating: "k", count: 32))
        let result = try await WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity).prepare()
        let prepared = try XCTUnwrap(result)
        let query = try XCTUnwrap(URLComponents(url: prepared.entry, resolvingAgainstBaseURL: false)?.percentEncodedQuery)
        let decoded = try codec.decode(Data(query.utf8), key: environment.entryKey)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: decoded) as? [String: String])
        XCTAssertEqual(fields[IntegrationConstants.ShortField.terms], "https://docs.google.com/document/d/1_n_EIH15GouK_fi39pvzv2okSYAd1Z8SnJZSB32UjDs/edit?tab=t.0")
        XCTAssertEqual(fields[IntegrationConstants.ShortField.privacy], "https://docs.google.com/document/d/1m9yUn_udhrEuamoTg9p8Obmc6sjTb2aIEx3u5Fk-yBI/edit?tab=t.0")
    }

    func testMissingConfigurationStopsBeforeNetwork() async throws {
        XCTAssertThrowsError(try WebEnvironment(values: [:]))
    }

    func testDeviceOfflineFailureIsNotCollapsedIntoGenericPageFailure() async throws {
        XCTAssertEqual(WebURLTransport.failure(for: URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(WebURLTransport.failure(for: URLError(.cannotConnectToHost)), .network)
    }

    func testLaunchMaterialIsValidatedAndRetainedForLaterDeviceLaunches() async throws {
        let material = String(repeating: "z", count: 32)
        var saved: String?
        let first = try WebEntryMaterialResolver.resolve(override: material, cached: nil) { saved = $0 }
        XCTAssertEqual(first, material)
        XCTAssertEqual(saved, material)
        let later = try WebEntryMaterialResolver.resolve(override: nil, cached: saved) { _ in XCTFail("No rewrite needed") }
        XCTAssertEqual(later, material)
        XCTAssertThrowsError(try WebEntryMaterialResolver.resolve(override: "short", cached: material) { _ in XCTFail("Invalid value persisted") })
        XCTAssertNil(try WebEntryMaterialResolver.resolve(override: nil, cached: nil) { _ in XCTFail("No material to save") })
    }

    func testTestConfigurationCanStartBeforeRemoteWebAddressArrives() async throws {
        let environment = try WebEnvironment(values: IntegrationConstants.testEnvironmentValues)
        XCTAssertEqual(environment.api.host, "test-app.dirtan.work")
        XCTAssertEqual(environment.terms?.absoluteString, IntegrationConstants.Legal.terms)
        XCTAssertEqual(environment.privacy?.absoluteString, IntegrationConstants.Legal.privacy)
        let selected = try environment.selecting(web: URL(string: "https://pages.dirtan.work")!)
        XCTAssertTrue(selected.webPolicy.allows(URL(string: "https://pages.dirtan.work/h5_web/drtest/")!))
        XCTAssertFalse(selected.webPolicy.allows(URL(string: "https://other.dirtan.work/h5_web/drtest/")!))
        XCTAssertThrowsError(try environment.selecting(web: URL(string: "https://dirtan.work.evil.test")!))
        XCTAssertThrowsError(try environment.selecting(web: URL(string: "https://evildirtan.work")!))
        XCTAssertThrowsError(try environment.selecting(web: URL(string: "http://pages.dirtan.work")!))
    }

    func testMissingEntryMaterialCannotProduceAnUnauthenticatedPage() async throws {
        let environment = try WebEnvironment(values: IntegrationConstants.testEnvironmentValues)
        let selected = try environment.selecting(web: URL(string: "https://pages.dirtan.work")!)
        XCTAssertThrowsError(try WebEntryBuilder(codec: WebCompatibilityCodec()).build(environment: selected,
            session: WebSession(userID: "synthetic-user", credential: "synthetic-session"),
            services: WebRemoteServices(web: URL(string: "https://pages.dirtan.work")!, messaging: nil, events: nil, contactID: nil),
            segment: "drtest", identity: Self.identity)) { error in
            XCTAssertEqual(error as? WebIntegrationError, .missingEntryMaterial)
        }
        XCTAssertEqual(IntegrationConstants.Catalog.productIDs.count, 10)
        XCTAssertEqual(Set(IntegrationConstants.Catalog.productIDs).count, 10)
    }

    func testAddressPolicyRejectsLookalikesAndUnsafeRoutes() async throws {
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        XCTAssertTrue(policy.allows(URL(string: "https://web.example.test/h5_web/app/#/")!))
        for value in ["http://web.example.test/h5_web/", "https://web.example.test.evil.test/h5_web/",
                      "https://web.example.test:444/h5_web/", "https://user@web.example.test/h5_web/",
                      "https://web.example.test/admin", "https://web.example.test/h5_web/../admin",
                      "https://web.example.test/h5_web/%2e%2e/admin"] {
            XCTAssertFalse(policy.allows(URL(string: value)!), value)
        }
    }

    func testCompatibilityCodecRoundTripsAndRejectsInvalidData() async throws {
        let codec = WebCompatibilityCodec()
        let input = Data("Hello 世界 +/= 🧵".utf8)
        let key = String(repeating: "x", count: 32)
        XCTAssertEqual(try codec.decode(codec.encode(input, key: key), key: key), input)
        XCTAssertThrowsError(try codec.decode(Data("invalid".utf8), key: key))
        XCTAssertThrowsError(try codec.encode(input, key: ""))
        XCTAssertThrowsError(try codec.encode(input, key: "中文"))
    }

    func testResponseRequiresNumericSuccessAndObject() async throws {
        XCTAssertThrowsError(try WebResponse.object(Data("{\"code\":true,\"data\":{}}".utf8)))
        XCTAssertThrowsError(try WebResponse.object(Data("{\"code\":1,\"data\":{}}".utf8)))
        XCTAssertThrowsError(try WebResponse.object(Data("{\"code\":0,\"data\":true}".utf8)))
        XCTAssertNotNil(try WebResponse.object(Data("{\"code\":0,\"data\":{}}".utf8)))
    }

    func testBridgeRequiresTrustedMainFrameAndExactBoolean() async throws {
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        let parser = WebBridgeParser(policy: policy)
        let source = URL(string: "https://web.example.test/h5_web/app/")!
        XCTAssertEqual(try parser.parse(URL(string: "go://g?t_pams=true")!, source: source, mainFrame: true), .keepAwake(true))
        XCTAssertThrowsError(try parser.parse(URL(string: "go://g?t_pams=yes")!, source: source, mainFrame: true))
        XCTAssertThrowsError(try parser.parse(URL(string: "go://g?t_pams=true")!, source: source, mainFrame: false))
        XCTAssertThrowsError(try parser.parse(URL(string: "go://f")!, source: URL(string: "https://evil.test/")!, mainFrame: true))
        XCTAssertEqual(try parser.parse(URL(string: "go://unknown")!, source: source, mainFrame: true), .ignored)
        XCTAssertThrowsError(try parser.parse(URL(string: "go://g?t_pams=true&t_pams=false")!, source: source, mainFrame: true))
    }

    func testUnknownActionsAreIgnoredWithoutSkippingSourceOrEnvelopeValidation() async throws {
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        let parser = WebBridgeParser(policy: policy)
        let source = URL(string: "https://web.example.test/h5_web/app/")!
        for raw in ["go://unknown", "go://unknown?t_pams=opaque"] {
            let url = try XCTUnwrap(URL(string: raw))
            for availability: WebBridgeAvailability in [.loading, .ready, .hidden] {
                XCTAssertEqual(try parser.parse(url, source: source, mainFrame: true, availability: availability), .ignored)
            }
            XCTAssertThrowsError(try parser.parse(url, source: URL(string: "https://outside.example.test/")!, mainFrame: true))
            XCTAssertThrowsError(try parser.parse(url, source: source, mainFrame: false))
        }
        for raw in ["go://unknown?unexpected=opaque", "go://unknown?t_pams=one&t_pams=two", "go://unknown/path", "go://unknown#fragment"] {
            XCTAssertThrowsError(try parser.parse(URL(string: raw)!, source: source, mainFrame: true))
        }
    }

    func testInitializationBridgeActionsCanRunWhileTheTrustedPageIsLoading() async throws {
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        let parser = WebBridgeParser(policy: policy)
        let source = URL(string: "https://web.example.test/h5_web/app/")!
        let history = URL(string: "go://i?t_pams=false")!
        let awake = URL(string: "go://g?t_pams=true")!
        XCTAssertEqual(try parser.parse(history, source: source, mainFrame: true, availability: .loading), .history(false))
        XCTAssertEqual(try parser.parse(awake, source: source, mainFrame: true, availability: .loading), .keepAwake(true))
        XCTAssertThrowsError(try parser.parse(history, source: source, mainFrame: true, availability: .hidden))
        XCTAssertThrowsError(try parser.parse(history, source: URL(string: "https://outside.example.test/")!, mainFrame: true, availability: .loading))
        XCTAssertThrowsError(try parser.parse(history, source: source, mainFrame: false, availability: .loading))
    }

    func testActionDiagnosticsIdentifyTheCommandWithoutItsArguments() async throws {
        let commands: [WebBridgeCommand] = [.endSession, .internalPage(URL(string: "https://web.example.test/")!),
            .externalPage(URL(string: "https://web.example.test/")!), .event(Data("secret-event".utf8)),
            .transaction(Data("secret-order".utf8)), .settings, .keepAwake(true), .close, .history(false), .contact]
        XCTAssertEqual(commands.map(\.actionID), ["a", "b", "c", "d", "e", "f", "g", "h", "i", "vs"])
        let url = URL(string: "go://e?t_pams=secret-order")!
        XCTAssertEqual(WebBridgeParser.actionID(for: url), "e")
        XCTAssertEqual(WebBridgeParser.actionID(for: URL(string: "go://unknown?t_pams=secret")!), IntegrationConstants.Diagnostic.unknownAction)
        XCTAssertEqual(WebBridgeParser.actionID(for: URL(string: "https://e/?token=secret")!), IntegrationConstants.Diagnostic.unknownAction)
    }

    func testBrowserActionsAreIndependentOfTheEntryPath() async throws {
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        let router = WebLinkRouter(policy: policy)
        let entry = URL(string: "https://web.example.test/h5_web/app/#/detail")!
        let help = URL(string: "https://support.example.test/help")!
        let otherPath = URL(string: "https://web.example.test/help")!
        XCTAssertEqual(try router.destination(for: .internalPage(entry)), .page(entry))
        XCTAssertEqual(try router.destination(for: .internalPage(help)), .browser(help))
        XCTAssertEqual(try router.destination(for: .internalPage(otherPath)), .browser(otherPath))
        XCTAssertEqual(try router.destination(for: .externalPage(help)), .system(help))
        XCTAssertEqual(try router.destination(for: .externalPage(entry)), .system(entry))
        for raw in ["javascript:alert(1)", "file:///tmp/page", "https://user:secret@support.example.test/help", "data:text/html,unsafe", "app-settings:"] {
            let url = try XCTUnwrap(URL(string: raw))
            XCTAssertThrowsError(try router.destination(for: .internalPage(url)))
            XCTAssertThrowsError(try router.destination(for: .externalPage(url)))
        }
        XCTAssertThrowsError(try router.destination(for: .settings))
        // External destinations never become privileged bridge sources.
        let parser = WebBridgeParser(policy: policy)
        XCTAssertThrowsError(try parser.parse(URL(string: "go://f")!, source: help, mainFrame: true))
    }

    func testWebRedirectsRemainInWebKitAndAppLinksUseTheSystem() async throws {
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        let router = WebLinkRouter(policy: policy)
        let source = URL(string: "https://web.example.test/h5_web/app/")!
        let outside = URL(string: "https://provider.example.test/checkout")!
        for activated in [true, false] {
            XCTAssertEqual(router.navigation(to: outside, source: source, sourceMainFrame: true, targetMainFrame: true, userActivated: activated, active: true), .allow)
            XCTAssertEqual(router.navigation(to: outside, source: outside, sourceMainFrame: true, targetMainFrame: true, userActivated: activated, active: true), .allow)
        }
        // WebKit must create and load new windows to retain opener and form requests.
        XCTAssertEqual(router.navigation(to: outside, source: source, sourceMainFrame: true, targetMainFrame: nil, userActivated: false, active: true), .allow)
        XCTAssertEqual(router.navigation(to: outside, source: nil, sourceMainFrame: false, targetMainFrame: nil, userActivated: false, active: true), .cancel)
        XCTAssertEqual(router.navigation(to: outside, source: nil, sourceMainFrame: false, targetMainFrame: nil, userActivated: false, active: false, initialDocument: outside), .allow)
        XCTAssertEqual(router.navigation(to: outside, source: outside, sourceMainFrame: true, targetMainFrame: false, userActivated: false, active: true), .allow)
        XCTAssertEqual(router.navigation(to: source, source: nil, sourceMainFrame: true, targetMainFrame: nil, userActivated: false, active: false), .allow)
        let app = URL(string: "walletdemo://checkout?order=synthetic")!
        XCTAssertEqual(router.navigation(to: app, source: outside, sourceMainFrame: true, targetMainFrame: true, userActivated: false, active: true), .open(.system(app)))
        XCTAssertEqual(router.navigation(to: app, source: outside, sourceMainFrame: false, targetMainFrame: false, userActivated: false, active: true), .cancel)
        XCTAssertEqual(router.navigation(to: app, source: nil, sourceMainFrame: true, targetMainFrame: true, userActivated: true, active: true), .deny)
        XCTAssertEqual(router.navigation(to: app, source: outside, sourceMainFrame: true, targetMainFrame: true, userActivated: true, active: false), .deny)
        XCTAssertEqual(router.navigation(to: URL(string: "javascript:alert(1)")!, source: outside, sourceMainFrame: true, targetMainFrame: true, userActivated: true, active: true), .deny)
        XCTAssertEqual(router.navigation(to: URL(string: "about:blank")!, source: source, sourceMainFrame: true, targetMainFrame: nil, userActivated: false, active: true), .allow)
        XCTAssertEqual(router.navigation(to: URL(string: "about:blank")!, source: nil, sourceMainFrame: false, targetMainFrame: false, userActivated: false, active: true), .allow)
        var link = URLComponents(string: "go://c")!
        link.queryItems = [URLQueryItem(name: "t_pams", value: app.absoluteString)]
        XCTAssertEqual(try WebBridgeParser(policy: policy).parse(link.url!, source: source, mainFrame: true), .externalPage(app))
    }

    func testBrowserFrameMatchingDoesNotGiveExternalPagesPrivilegedCommands() async throws {
        let document = URL(string: "http://provider.example.test:8080/checkout")!
        let frame = WebFrameSource(mainFrame: true, scheme: "http", host: "provider.example.test", port: 8080)
        XCTAssertEqual(frame.matchingPageURL(document), document)
        XCTAssertNil(WebFrameSource(mainFrame: true, scheme: "http", host: "provider.example.test", port: 0).matchingPageURL(document))
        let policy = try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["/h5_web/"])
        XCTAssertNil(frame.trustedPageURL(document, policy: policy))
        let parser = WebBridgeParser(policy: policy)
        XCTAssertEqual(try parser.parseBrowser(URL(string: "go://h")!, source: document, mainFrame: true), .close)
        XCTAssertEqual(try parser.parseBrowser(URL(string: "go://c?t_pams=walletdemo%3A%2F%2Fcheckout")!, source: document, mainFrame: true), .externalPage(URL(string: "walletdemo://checkout")!))
        XCTAssertEqual(try parser.parseBrowser(URL(string: "go://i?t_pams=false")!, source: document, mainFrame: true), .history(false))
        XCTAssertEqual(try parser.parseBrowser(URL(string: "go://b?t_pams=https%3A%2F%2Fbank.example.test%2Fverify")!, source: document, mainFrame: true), .internalPage(URL(string: "https://bank.example.test/verify")!))
        XCTAssertEqual(try parser.parseBrowser(URL(string: "go://unknown")!, source: document, mainFrame: true), .ignored)
        for raw in ["go://f", "go://e?t_pams=%7B%7D", "go://a", "go://h?t_pams=unexpected"] {
            XCTAssertThrowsError(try parser.parseBrowser(URL(string: raw)!, source: document, mainFrame: true))
        }
        XCTAssertThrowsError(try parser.parseBrowser(URL(string: "go://h")!, source: document, mainFrame: false))
        XCTAssertThrowsError(try parser.parseBrowser(URL(string: "go://h")!, source: nil, mainFrame: true))
        XCTAssertThrowsError(try WebBridgeParser(policy: policy).parse(URL(string: "go://e?t_pams=%7B%7D")!, source: document, mainFrame: true))
        let router = WebLinkRouter(policy: policy)
        XCTAssertEqual(try router.destination(for: .internalPage(document)), .browser(document))
        XCTAssertEqual(try router.destination(for: .externalPage(URL(string: "walletdemo://checkout")!)), .system(URL(string: "walletdemo://checkout")!))
        XCTAssertThrowsError(try router.destination(for: .internalPage(URL(string: "walletdemo://checkout")!)))
    }

    func testEntryContainsAllShortFieldsAndNeverUsesPlainCredentials() async throws {
        let environment = try Self.environment()
        let codec = WebCompatibilityCodec()
        let session = WebSession(userID: "synthetic-user", credential: "synthetic-session")
        let services = WebRemoteServices(web: URL(string: "https://web.example.test")!, messaging: nil, events: nil, contactID: nil)
        let entry = try WebEntryBuilder(codec: codec).build(environment: environment, session: session,
            services: services, segment: "app", identity: Self.identity)
        XCTAssertFalse(entry.absoluteString.contains(session.credential))
        let carrier = try XCTUnwrap(URLComponents(url: entry, resolvingAgainstBaseURL: false)?.percentEncodedQuery)
        let plain = try codec.decode(Data(carrier.utf8), key: environment.entryKey)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: plain) as? [String: String])
        XCTAssertEqual(fields.count, 13)
        XCTAssertEqual(fields[IntegrationConstants.ShortField.credential], session.credential)
        XCTAssertEqual(fields[IntegrationConstants.ShortField.partOne], environment.partFields[0])
        XCTAssertThrowsError(try WebEntryBuilder(codec: codec).build(environment: environment, session: session,
            services: services, segment: "../admin", identity: Self.identity))
    }

    func testNativeStrategyDoesNotRequireWebAddressOrEntryMaterial() async throws {
        var values = IntegrationConstants.testEnvironmentValues
        values[IntegrationConstants.Configuration.entryKey] = ""
        let environment = try WebEnvironment(values: values)
        let codec = WebCompatibilityCodec()
        let transport = try Self.transport(codec: codec, environment: environment)
        let response: [String: Any] = ["code": 0, "data": ["isReviewPkg": true]]
        transport.responses[2] = try codec.encode(JSONSerialization.data(withJSONObject: response), key: String(repeating: "k", count: 32))
        let service = WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity)
        let coordinator = WebIntegrationCoordinator { service }
        coordinator.start()
        for _ in 0..<100 where coordinator.state == .connecting { await Task.yield() }
        XCTAssertEqual(coordinator.state, .native)
        XCTAssertNil(coordinator.prepared)
        XCTAssertNil(coordinator.diagnostic)
        XCTAssertEqual(transport.requests.count, 3)
    }

    func testMissingOrMalformedStrategyCannotOpenWebpage() async throws {
        let environment = try Self.environment()
        let codec = WebCompatibilityCodec()
        for flag: Any in [NSNull(), "false", 0, 1, [:]] {
            let transport = try Self.transport(codec: codec, environment: environment)
            var payload: [String: Any] = ["data": ["dr": ["https://web.example.test"]]]
            if !(flag is NSNull) { payload["isReviewPkg"] = flag }
            let response: [String: Any] = ["code": 0, "data": payload]
            transport.responses[2] = try codec.encode(JSONSerialization.data(withJSONObject: response), key: String(repeating: "k", count: 32))
            let service = WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity)
            do { _ = try await service.prepare(); XCTFail("Expected invalid strategy") }
            catch let failure as WebStartupFailure {
                XCTAssertEqual(failure.stage, .directory)
                XCTAssertEqual(failure.reason, .malformedResponse)
            }
        }
    }

    func testWebStrategyRunsThreeRequestsAndPreparesWebpage() async throws {
        let environment = try Self.environment()
        let codec = WebCompatibilityCodec()
        let transport = try Self.transport(codec: codec, environment: environment)
        let service = WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity)
        let prepared = try await service.prepare()
        let result = try XCTUnwrap(prepared)
        XCTAssertEqual(transport.requests.map { $0.url!.path }, IntegrationConstants.Endpoint.startup)
        XCTAssertEqual(result.session.userID, "synthetic-user")
        XCTAssertEqual(result.entry.host, "web.example.test")
        XCTAssertEqual(transport.requests.count, 3)
    }

    func testOptionalDirectoryValuesDoNotBlockTheWebpage() async throws {
        for extras: [Any] in [[NSNull(), NSNull()], ["wss://unconfigured.example.test/socket", "invalid"]] {
            let environment = try Self.environment()
            let codec = WebCompatibilityCodec()
            let transport = try Self.transport(codec: codec, environment: environment)
            let response: [String: Any] = ["code": 0, "data": ["isReviewPkg": false, "data": ["dr": ["https://web.example.test"] + extras]]]
            transport.responses[2] = try codec.encode(JSONSerialization.data(withJSONObject: response), key: String(repeating: "k", count: 32))
            let service = WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity)
            let prepared = try await service.prepare()
            let result = try XCTUnwrap(prepared)
            XCTAssertEqual(result.entry.host, "web.example.test")
            XCTAssertNil(result.services.messaging)
            XCTAssertNil(result.services.events)
        }
    }

    func testConfiguredServicesCannotBeReplacedByAnotherRemoteEnvironment() async throws {
        var values = IntegrationConstants.testEnvironmentValues
        values[IntegrationConstants.Configuration.entryKey] = String(repeating: "e", count: 32)
        let environment = try WebEnvironment(values: values)
        let codec = WebCompatibilityCodec()
        let transport = try Self.transport(codec: codec, environment: environment)
        let response: [String: Any] = ["code": 0, "data": ["isReviewPkg": false, "data": ["dr": [
            "https://test-h5.tipobox.cc", "wss://test-im.tipobox.cc", "https://test-log.tipobox.cc"
        ]]]]
        transport.responses[2] = try codec.encode(JSONSerialization.data(withJSONObject: response), key: String(repeating: "k", count: 32))
        let prepared = try await WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity).prepare()
        let result = try XCTUnwrap(prepared)
        XCTAssertEqual(result.entry.host, "test-h5.tipobox.cc")
        XCTAssertEqual(URLComponents(url: result.entry, resolvingAgainstBaseURL: false)?.percentEncodedPath, "/h5_web/drtest/")
        XCTAssertTrue(result.environment.webPolicy.allows(result.entry))
        XCTAssertFalse(result.environment.webPolicy.allows(URL(string: "https://other.tipobox.cc/h5_web/drtest/")!))
        XCTAssertFalse(result.environment.webPolicy.allows(URL(string: "https://test-h5.tipobox.cc.evil.test/h5_web/drtest/")!))
        XCTAssertEqual(result.services.messaging?.absoluteString, IntegrationConstants.Host.messaging)
        XCTAssertEqual(result.services.events?.absoluteString, IntegrationConstants.Host.events)
        let query = try XCTUnwrap(URLComponents(url: result.entry, resolvingAgainstBaseURL: false)?.percentEncodedQuery)
        let decoded = try codec.decode(Data(query.utf8), key: environment.entryKey)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: decoded) as? [String: String])
        XCTAssertEqual(fields[IntegrationConstants.ShortField.messaging], IntegrationConstants.Host.messaging + "/")
        XCTAssertEqual(fields[IntegrationConstants.ShortField.events], IntegrationConstants.Host.events + "/")
    }

    func testMissingDirectoryAddressIsDifferentFromAnUntrustedAddress() async throws {
        let environment = try Self.environment()
        let codec = WebCompatibilityCodec()
        for domains: [Any] in [[], [NSNull(), "", ""]] {
            let transport = try Self.transport(codec: codec, environment: environment)
            let response: [String: Any] = ["code": 0, "data": ["isReviewPkg": false, "data": ["dr": domains]]]
            transport.responses[2] = try codec.encode(JSONSerialization.data(withJSONObject: response), key: String(repeating: "k", count: 32))
            let service = WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity)
            do { _ = try await service.prepare(); XCTFail("Expected missing webpage address") }
            catch let error as WebStartupFailure {
                XCTAssertEqual(error.reason, .servicesUnavailable)
                XCTAssertEqual(error.reference, "H5-3-R12")
                XCTAssertNil(error.endpoints?.webOrigin)
            }
        }
    }

    func testDirectoryDiagnosticsExposeOriginsWithoutCredentialsOrQueries() async throws {
        let environment = try Self.environment()
        let codec = WebCompatibilityCodec()
        let transport = try Self.transport(codec: codec, environment: environment)
        let domains = ["https://name:synthetic-secret@outside.example.test/private?token=synthetic-session", "wss://messages.example.test/socket?token=synthetic-session", ""]
        let response: [String: Any] = ["code": 0, "data": ["isReviewPkg": false, "data": ["dr": domains]]]
        transport.responses[2] = try codec.encode(JSONSerialization.data(withJSONObject: response), key: String(repeating: "k", count: 32))
        let service = WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity)
        do { _ = try await service.prepare(); XCTFail("Expected untrusted webpage address") }
        catch let error as WebStartupFailure {
            XCTAssertEqual(error.reference, "H5-3-R7")
            XCTAssertEqual(error.endpoints?.webOrigin, "https://outside.example.test")
            let text = try XCTUnwrap(error.endpoints?.description)
            for forbidden in ["synthetic-secret", "synthetic-session", "private", "socket", "token", "name:"] {
                XCTAssertFalse(text.contains(forbidden))
            }
        }
    }

    func testStartupPreservesConfigurationNetworkErrorCode() async throws {
        let environment = try Self.environment()
        let transport = WebTestTransport(responses: [])
        transport.failure = WebTransportFailure(reason: .offline, nativeCode: NSURLErrorNotConnectedToInternet)
        let service = WebStartupService(environment: environment, transport: transport, codec: WebCompatibilityCodec(), identity: Self.identity)
        do { _ = try await service.prepare(); XCTFail("Expected network failure") }
        catch let error as WebStartupFailure {
            XCTAssertEqual(error.stage, .configuration)
            XCTAssertEqual(error.reason, .offline)
            XCTAssertEqual(error.reference, "H5-1-U-1009")
            XCTAssertEqual(transport.requests.count, 1)
        }
    }

    func testMissingNestedIdentityStopsAtAuthenticationWithSafeReference() async throws {
        let environment = try Self.environment()
        let codec = WebCompatibilityCodec()
        let transport = try Self.transport(codec: codec, environment: environment)
        let flat: [String: Any] = ["code": 0, "data": ["userId": "synthetic-user", "token": "synthetic-session"]]
        transport.responses[1] = try codec.encode(JSONSerialization.data(withJSONObject: flat), key: String(repeating: "k", count: 32))
        let service = WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity)
        do { _ = try await service.prepare(); XCTFail("Expected invalid identity structure") }
        catch let error as WebStartupFailure {
            XCTAssertEqual(error.stage, .authentication)
            XCTAssertEqual(error.reference, "H5-2-R2")
            XCTAssertEqual(transport.requests.count, 2)
            XCTAssertFalse(error.reference.contains("synthetic-session"))
        }
    }

    func testMalformedConfigurationDoesNotContinueAuthentication() async throws {
        let environment = try Self.environment()
        let codec = WebCompatibilityCodec()
        let bad = try codec.encode(Data("{\"code\":0,\"data\":{}}".utf8), key: environment.api.host!)
        let transport = WebTestTransport(responses: [bad])
        let service = WebStartupService(environment: environment, transport: transport, codec: codec, identity: Self.identity)
        do { _ = try await service.prepare(); XCTFail("Expected invalid configuration") } catch {}
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testDisabledCapabilitiesReturnUnsupported() async throws {
        let handler = WebDisabledCapabilities()
        do { try await handler.perform(.transaction(Data())); XCTFail("Expected unsupported capability") }
        catch { XCTAssertEqual(error as? WebIntegrationError, .unsupported) }
    }

    func testCoordinatorPublishesReadyAndClearsSessionOnClose() async throws {
        let environment = try Self.environment()
        let codec = WebCompatibilityCodec()
        let service = WebStartupService(environment: environment, transport: try Self.transport(codec: codec, environment: environment), codec: codec, identity: Self.identity)
        let coordinator = WebIntegrationCoordinator { service }
        coordinator.start()
        for _ in 0..<100 where coordinator.state == .connecting { await Task.yield() }
        XCTAssertEqual(coordinator.state, .ready)
        XCTAssertNotNil(coordinator.prepared)
        coordinator.cancel()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertNil(coordinator.prepared)
    }

    func testCoordinatorDeadlineAndCancellationCannotPublishLateResult() async throws {
        let service = WebDelayedService()
        let coordinator = WebIntegrationCoordinator(timeout: 1_000_000) { service }
        coordinator.start()
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(coordinator.state, .failed(.network))
        XCTAssertNil(coordinator.prepared)
        coordinator.start()
        coordinator.cancel()
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertNil(coordinator.prepared)
    }

    func testCoordinatorConfigurationFailureEndsLoadingImmediately() async throws {
        let coordinator = WebIntegrationCoordinator { throw WebIntegrationError.unavailable }
        coordinator.start()
        XCTAssertEqual(coordinator.state, .failed(.unavailable))
    }

    func testBridgeParsesDeclaredActionsAndRejectsInvalidObjects() async throws {
        let parser = WebBridgeParser(policy: try WebAddressPolicy(origins: ["https://web.example.test"]))
        let source = URL(string: "https://web.example.test/")!
        for (action, expected) in [("a", WebBridgeCommand.endSession), ("f", .settings), ("h", .close), ("vs", .contact)] {
            XCTAssertEqual(try parser.parse(URL(string: "go://" + action)!, source: source, mainFrame: true), expected)
        }
        XCTAssertEqual(try parser.parse(URL(string: "go://i?t_pams=false")!, source: source, mainFrame: true), .history(false))
        for action in ["b", "c"] {
            var parts = URLComponents(string: "go://" + action)!
            parts.queryItems = [URLQueryItem(name: "t_pams", value: "https://web.example.test/page")]
            let expected: WebBridgeCommand = action == "b" ? .internalPage(URL(string: "https://web.example.test/page")!) : .externalPage(URL(string: "https://web.example.test/page")!)
            XCTAssertEqual(try parser.parse(parts.url!, source: source, mainFrame: true), expected)
        }
        for action in ["d", "e"] {
            var parts = URLComponents(string: "go://" + action)!
            parts.queryItems = [URLQueryItem(name: "t_pams", value: "{}")]
            _ = try parser.parse(parts.url!, source: source, mainFrame: true)
            parts.queryItems = [URLQueryItem(name: "t_pams", value: "[]")]
            XCTAssertThrowsError(try parser.parse(parts.url!, source: source, mainFrame: true))
        }
        for input in ["go://f?t_pams=unexpected", "go://f/path", "go://f#fragment", "go://b?t_pams=javascript:alert(1)"] {
            XCTAssertThrowsError(try parser.parse(URL(string: input)!, source: source, mainFrame: true))
        }
    }

    func testInvalidEnvironmentIsRejected() async throws {
        XCTAssertThrowsError(try WebAddressPolicy(origins: ["https://web.example.test/path"]))
        XCTAssertThrowsError(try WebAddressPolicy(origins: []))
        XCTAssertThrowsError(try WebAddressPolicy(origins: ["https://web.example.test"], pathPrefixes: ["relative"]))
        XCTAssertThrowsError(try WebEnvironment(values: [IntegrationConstants.Configuration.confirmed: false]))
    }

    static let identity = WebClientIdentity(installation: "synthetic-install", bundle: "test.integration", version: "1", name: "Test", model: "Test", system: "17", language: "en", region: "US", zone: "UTC", locale: "en_US")

    static func environment() throws -> WebEnvironment {
        try WebEnvironment(values: [
            IntegrationConstants.Configuration.environment: "test",
            IntegrationConstants.Configuration.api: "https://api.example.test",
            IntegrationConstants.Configuration.origins: ["https://web.example.test"],
            IntegrationConstants.Configuration.paths: ["/h5_web/"],
            IntegrationConstants.Configuration.serviceOrigins: [],
            IntegrationConstants.Configuration.externalOrigins: ["https://support.example.test"],
            IntegrationConstants.Configuration.terms: "https://support.example.test/terms",
            IntegrationConstants.Configuration.privacy: "https://support.example.test/privacy",
            IntegrationConstants.Configuration.partFields: ["partOne", "partTwo", "partThree"],
            IntegrationConstants.Configuration.entryKey: String(repeating: "e", count: 32),
            IntegrationConstants.Configuration.confirmed: true
        ])
    }

    static func transport(codec: WebCompatibilityCodec, environment: WebEnvironment) throws -> WebTestTransport {
        let key = String(repeating: "k", count: 32)
        let content: [String: Any] = ["items": [["name": "app_ext_data", "data": ["config_h5app_urlpath": "app"]]]]
        let inner = try codec.encode(JSONSerialization.data(withJSONObject: content), key: key)
        let config: [String: Any] = ["code": 0, "data": [
            environment.partFields[0]: Data(key.prefix(16).utf8).base64EncodedString(),
            environment.partFields[1]: Data(key.suffix(16).utf8).base64EncodedString(),
            environment.partFields[2]: inner.base64EncodedString()
        ]]
        let session: [String: Any] = ["code": 0, "data": ["userInfo": ["userId": "synthetic-user"], "token": "synthetic-session"]]
        let services: [String: Any] = ["code": 0, "data": ["isReviewPkg": false, "data": ["dr": ["https://web.example.test", "", ""]]]]
        return WebTestTransport(responses: try [
            codec.encode(JSONSerialization.data(withJSONObject: config), key: environment.api.host!),
            codec.encode(JSONSerialization.data(withJSONObject: session), key: key),
            codec.encode(JSONSerialization.data(withJSONObject: services), key: key)
        ])
    }
}

@MainActor
final class WebDelayedService: WebSessionPreparing {
    func prepare() async throws -> WebPreparedSession? {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        throw WebIntegrationError.network
    }
}

@MainActor
final class WebTestTransport: WebTransport {
    var responses: [Data]
    var failure: Error?
    var requests: [URLRequest] = []
    init(responses: [Data]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> Data {
        requests.append(request)
        if let failure { throw failure }
        guard !responses.isEmpty else { throw WebIntegrationError.network }
        return responses.removeFirst()
    }
}
