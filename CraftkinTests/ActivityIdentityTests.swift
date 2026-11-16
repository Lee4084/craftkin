import XCTest
import Security
@testable import Craftkin

@MainActor
final class ActivityIdentityTests: XCTestCase {
    private let first = "11111111-1111-4111-8111-111111111111"
    private let second = "22222222-2222-4222-8222-222222222222"

    func testMigratesExistingH5IdentityAndReusesItFromAnotherStoreInstance() throws {
        let account = "test.activity." + UUID().uuidString
        defer { remove(account) }
        let store = WebActivityIdentityStore(account: account)
        XCTAssertNil(try store.read())
        XCTAssertEqual(try store.resolve(migrating: first), first)
        let nextInstall = WebActivityIdentityStore(account: account)
        XCTAssertEqual(try nextInstall.read(), first)
        XCTAssertEqual(try nextInstall.resolve(migrating: second), first)
    }

    func testNewIdentityIsCreatedOnlyOnce() throws {
        let account = "test.activity." + UUID().uuidString
        defer { remove(account) }
        let store = WebActivityIdentityStore(account: account)
        let created = try store.resolve(migrating: nil)
        XCTAssertTrue(WebActivityIdentityStore.isValid(created))
        XCTAssertEqual(try WebActivityIdentityStore(account: account).resolve(migrating: nil), created)
    }

    func testMalformedIdentityDoesNotCreateOrReplaceKeychainRecord() throws {
        let account = "test.activity." + UUID().uuidString
        defer { remove(account) }
        let store = WebActivityIdentityStore(account: account)
        for value in ["", "not-a-uuid", first + "&token=private"] {
            XCTAssertThrowsError(try store.resolve(migrating: value))
            XCTAssertNil(try store.read())
        }
        try WebSecureStore().write("invalid-stored-value", account: account)
        XCTAssertThrowsError(try store.resolve(migrating: first))
        XCTAssertEqual(try WebSecureStore().read(account), "invalid-stored-value")
    }

    func testPreparedEntryPassesStoredIdentityAsSingleURLParameter() async throws {
        let entry = URL(string: "https://entry.example.test/")!
        let result = try await WebActivityEntryService(entry: entry, readDeviceID: { self.first }).prepare()
        let prepared = try XCTUnwrap(result)
        let parts = try XCTUnwrap(URLComponents(url: prepared.entry, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.queryItems, [URLQueryItem(name: "deviceid", value: first)])
        XCTAssertEqual(prepared.entry.host, entry.host)
        XCTAssertTrue(prepared.session.credential.isEmpty)
        XCTAssertTrue(prepared.environment.webPolicy.allows(prepared.entry))
    }

    func testInvalidOrUnavailableKeychainDoesNotSilentlyCreateAnotherUser() async {
        let entry = URL(string: "https://entry.example.test/")!
        for read in [{ "invalid" } as () throws -> String?, { throw WebIntegrationError.unavailable }] {
            do {
                _ = try await WebActivityEntryService(entry: entry, readDeviceID: read).prepare()
                XCTFail("Invalid or unreadable identity must stop startup")
            } catch {}
        }
    }

    func testMigrationBridgeOnlyAcceptsExpectedEntryMainFrameAndUUID() throws {
        let source = URL(string: "https://entry.example.test/")!
        var migrated: [String?] = []
        let bridge = WebActivityIdentityBridge(entry: source) { candidate in
            migrated.append(candidate)
            return candidate ?? self.first
        }
        let frame = WebFrameSource(mainFrame: true, scheme: "https", host: "entry.example.test", port: 443)
        XCTAssertEqual(try bridge.resolve(["installation": first], source: source, frame: frame), first)
        XCTAssertEqual(try bridge.resolve(["installation": NSNull()], source: source, frame: frame), first)
        XCTAssertEqual(migrated.count, 2)
        let child = WebFrameSource(mainFrame: false, scheme: "https", host: "entry.example.test", port: 443)
        for (body, url, snapshot) in [
            (["installation": first] as [String: Any], source, child),
            (["installation": first], URL(string: "https://other.example.test/")!, frame),
            (["installation": first], URL(string: "https://entry.example.test/other")!, frame),
            (["installation": "invalid"], source, frame),
            (["installation": first, "extra": "value"], source, frame)
        ] {
            XCTAssertThrowsError(try bridge.resolve(body, source: url, frame: snapshot))
        }
        XCTAssertEqual(migrated.count, 2)
    }

    private func remove(_ account: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: IntegrationConstants.Storage.service,
            kSecAttrAccount as String: account] as CFDictionary)
    }
}
