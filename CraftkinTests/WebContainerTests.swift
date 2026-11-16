#if canImport(UIKit)
import UIKit
import WebKit
import XCTest
@testable import Craftkin

@MainActor
final class WebContainerTests: XCTestCase {
    func testActivityBrowserChildAllowsExternalNavigationWhileEntryStaysRestricted() async throws {
        let entry = URL(string: "https://entry.example.test/")!
        let outside = URL(string: "https://provider.example.test/details")!
        let prepared = try await WebActivityEntryService(entry: entry).prepare()
        let session = try XCTUnwrap(prepared)
        for isBrowser in [false, true] {
            let controller = WebPageController(url: isBrowser ? outside : entry, session: session,
                dataStore: .nonPersistent(), capabilities: WebDisabledCapabilities(), onClose: {},
                showsNavigation: isBrowser, loadsInitialPage: false)
            controller.loadViewIfNeeded()
            let browser = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? WKWebView }.first)
            let received = expectation(description: "Navigation decision")
            var actual: WKNavigationActionPolicy?
            let recorder = NavigationDecisionRecorder(controller: controller, target: outside) { policy in
                actual = policy
                received.fulfill()
            }
            browser.navigationDelegate = recorder
            browser.load(URLRequest(url: outside))
            await fulfillment(of: [received], timeout: 15)
            XCTAssertEqual(actual, isBrowser ? .allow : .cancel)
            controller.stop()
        }
    }

    func testActivityBrowserChildAllowsExternalResponseWhileEntryStaysRestricted() async throws {
        let entry = URL(string: "https://entry.example.test/")!
        let outside = URL(string: "https://provider.example.test/details")!
        let prepared = try await WebActivityEntryService(entry: entry).prepare()
        let session = try XCTUnwrap(prepared)
        let response = HTTPURLResponse(url: outside, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "text/html"])!
        for isBrowser in [false, true] {
            let controller = WebPageController(url: isBrowser ? outside : entry, session: session,
                dataStore: .nonPersistent(), capabilities: WebDisabledCapabilities(), onClose: {},
                showsNavigation: isBrowser, loadsInitialPage: false)
            controller.loadViewIfNeeded()
            XCTAssertEqual(controller.navigationPolicy(for: response, mainFrame: true, canShowMIMEType: true),
                isBrowser ? .allow : .cancel)
            controller.stop()
        }
    }

    func testFailureKeepsFirstCauseUntilAnotherNavigationStarts() throws {
        let environment = try WebIntegrationTests.environment()
        let entry = URL(string: "https://web.example.test/h5_web/app/")!
        let session = WebPreparedSession(entry: entry,
            session: WebSession(userID: "synthetic-user", credential: "synthetic-session"),
            services: WebRemoteServices(web: URL(string: "https://web.example.test")!, messaging: nil, events: nil, contactID: nil),
            environment: environment)
        let controller = WebPageController(url: entry, session: session,
            dataStore: .nonPersistent(), capabilities: WebDisabledCapabilities(), onClose: {},
            loadsInitialPage: false)
        defer { controller.stop() }
        controller.loadViewIfNeeded()
        let browser = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? WKWebView }.first)
        let label = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIStackView }
            .flatMap(\.arrangedSubviews).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == IntegrationConstants.Text.unavailableID })

        controller.webView(browser, didFailProvisionalNavigation: nil,
            withError: WebTransportFailure(reason: .network, httpStatus: 404))
        XCTAssertTrue(label.text?.hasSuffix("H5-5-H404") == true)
        controller.webView(browser, didFailProvisionalNavigation: nil,
            withError: NSError(domain: "WebKitErrorDomain", code: 102))
        XCTAssertTrue(label.text?.hasSuffix("H5-5-H404") == true,
            "A follow-up cancellation must preserve the actual HTTP failure")

        controller.webView(browser, didStartProvisionalNavigation: nil)
        controller.webView(browser, didFailProvisionalNavigation: nil, withError: URLError(.timedOut))
        XCTAssertTrue(label.text?.hasSuffix("H5-5-U-1001") == true,
            "A new navigation must be able to report its own failure")
    }

    func testNewWindowUsesSuppliedConfigurationWithoutStartingAnotherGET() throws {
        let environment = try WebIntegrationTests.environment()
        let entry = URL(string: "https://web.example.test/h5_web/app/")!
        let session = WebPreparedSession(entry: entry,
            session: WebSession(userID: "synthetic-user", credential: "synthetic-session"),
            services: WebRemoteServices(web: URL(string: "https://web.example.test")!, messaging: nil, events: nil, contactID: nil),
            environment: environment)
        let store = WKWebsiteDataStore.nonPersistent()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = store
        configuration.applicationNameForUserAgent = "SyntheticWindow"
        let controller = WebPageController(url: URL(string: "https://provider.example.test/checkout")!,
            session: session, dataStore: store, capabilities: WebDisabledCapabilities(), onClose: {},
            showsNavigation: true, configuration: configuration, loadsInitialPage: false)
        defer { controller.stop() }
        controller.loadViewIfNeeded()
        let browser = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? WKWebView }.first)
        XCTAssertEqual(browser.configuration.applicationNameForUserAgent, "SyntheticWindow")
        XCTAssertTrue(browser.configuration.websiteDataStore === store)
        XCTAssertNil(browser.url)
        XCTAssertNotNil(controller.navigationItem.leftBarButtonItem?.image)
        XCTAssertEqual(controller.navigationItem.leftBarButtonItem?.accessibilityLabel, IntegrationConstants.Text.back)
        XCTAssertNil(controller.navigationItem.rightBarButtonItem)
    }
}

@MainActor
private final class NavigationDecisionRecorder: NSObject, WKNavigationDelegate {
    let controller: WebPageController
    let target: URL
    let onDecision: (WKNavigationActionPolicy) -> Void
    private var recorded = false
    init(controller: WebPageController, target: URL, onDecision: @escaping (WKNavigationActionPolicy) -> Void) {
        self.controller = controller; self.target = target; self.onDecision = onDecision
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard !recorded, navigationAction.request.url == target else { decisionHandler(.cancel); return }
        recorded = true
        controller.webView(webView, decidePolicyFor: navigationAction) { policy in
            self.onDecision(policy)
            // Observe the container's real decision without making a network request.
            decisionHandler(.cancel)
        }
    }
}


#endif
