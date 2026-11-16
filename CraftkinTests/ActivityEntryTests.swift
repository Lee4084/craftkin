import XCTest
@testable import Craftkin

@MainActor
final class ActivityEntryTests: XCTestCase {
    func testEntryPreparationUsesFixedURLWithoutCredentialsOrConfigurationRequests() async throws {
        let entry = URL(string: "https://entry.example.test/")!
        let result = try await WebActivityEntryService(entry: entry, readDeviceID: { nil }).prepare()
        let prepared = try XCTUnwrap(result)
        XCTAssertEqual(prepared.entry, entry)
        XCTAssertTrue(prepared.session.credential.isEmpty)
        XCTAssertTrue(prepared.session.userID.isEmpty)
        XCTAssertTrue(prepared.environment.webPolicy.allows(entry))
        XCTAssertFalse(prepared.environment.webPolicy.allows(URL(string: "https://untrusted.example.test/")!))
        XCTAssertTrue(prepared.isActivityEntry)
    }

    func testEntryRejectsInsecureURLAndURLCredentials() async {
        for value in ["http://entry.example.test/", "https://user:pass@entry.example.test/", "https://entry.example.test/?token=secret", "https://entry.example.test/#other"] {
            do {
                _ = try await WebActivityEntryService(entry: URL(string: value)!).prepare()
                XCTFail("Unsafe entry accepted")
            } catch {}
        }
    }

    func testActivityCallbackRequiresTrustedMainFrame() throws {
        let policy = try WebAddressPolicy(origins: ["https://entry.example.test"])
        let parser = WebBridgeParser(policy: policy)
        let callback = URL(string: "go://activitycontinue")!
        let source = URL(string: "https://entry.example.test/")!
        XCTAssertEqual(try parser.parse(callback, source: source, mainFrame: true), .continueNative)
        XCTAssertThrowsError(try parser.parse(callback, source: source, mainFrame: false))
        XCTAssertThrowsError(try parser.parseBrowser(callback, source: URL(string: "https://other.example.test/")!, mainFrame: true))
    }
}
