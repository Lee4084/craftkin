import XCTest

final class WebIntegrationUITests: XCTestCase {
    @MainActor
    func testConfirmedAgreementsAreVisibleInSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openProfile", "-familyRoute", "settings"]
        app.launch()
        let terms = app.descendants(matching: .any).matching(identifier: "legal-terms").firstMatch
        let privacy = app.descendants(matching: .any).matching(identifier: "legal-privacy").firstMatch
        XCTAssertTrue(terms.waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["screen-privacy-cover"].exists)
        for _ in 0..<4 where !privacy.isHittable { app.swipeUp() }
        XCTAssertTrue(privacy.exists)
    }

    @MainActor
    func testLoginRoutingFailureCanCloseAndRetryFromCompletion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-disableOnlineServices", "-resetOnboarding", "-icloudAvailable", "1"]
        app.launch()
        app.buttons["Get Started"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Set Up My Space"].tap()
        app.buttons["Create a Family Space"].tap()
        let name = app.textFields["Family Space name"]
        name.tap()
        name.typeText("Routing Test")
        app.buttons["Create Family Space"].tap()
        app.buttons["Continue to Library"].tap()
        XCTAssertTrue(app.staticTexts["online-services-unavailable"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.navigationBars.count, 0)
        app.buttons["online-services-close"].tap()
        XCTAssertTrue(app.buttons["Continue to Library"].waitForExistence(timeout: 5))
        app.buttons["Continue to Library"].tap()
        XCTAssertTrue(app.staticTexts["online-services-unavailable"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUnconfiguredServiceCanCloseBackToSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-disableOnlineServices", "-openLibrary", "-openProfile", "-familyRoute", "settings", "-libraryFixture", "populated"]
        app.launch()
        let entry = app.buttons["online-services-entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        entry.tap()
        XCTAssertTrue(app.staticTexts["online-services-unavailable"].waitForExistence(timeout: 5))
        app.buttons["online-services-close"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
    }
}
