#if canImport(UIKit)
import UIKit
import WebKit
import XCTest
@testable import Craftkin

@MainActor
final class WebContainerTests: XCTestCase {
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
#endif
