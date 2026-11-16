import Foundation
import WebKit

/// A dedicated key preserves the existing H5 identity during migration from web storage.
struct WebActivityIdentityStore {
    var account = IntegrationConstants.Storage.activityInstallation

    static func isValid(_ value: String) -> Bool {
        value.utf8.count == 36 && UUID(uuidString: value) != nil
    }

    func read() throws -> String? {
        guard let value = try WebSecureStore().read(account) else { return nil }
        guard Self.isValid(value) else { throw WebIntegrationError.unavailable }
        return value
    }

    func resolve(migrating candidate: String?) throws -> String {
        if let candidate, !Self.isValid(candidate) { throw WebIntegrationError.invalidMessage }
        if let existing = try read() { return existing }
        let value = candidate ?? UUID().uuidString.lowercased()
        let saved = try WebSecureStore().createIfAbsent(value, account: account)
        guard Self.isValid(saved) else { throw WebIntegrationError.unavailable }
        return saved
    }
}

@MainActor
final class WebActivityIdentityBridge: NSObject, WKScriptMessageHandlerWithReply {
    static let name = "activityDeviceID"
    weak var browser: WKWebView?
    private let entry: URL
    private let resolveID: (String?) throws -> String

    init(entry: URL, resolveID: ((String?) throws -> String)? = nil) {
        self.entry = entry
        self.resolveID = resolveID ?? { try WebActivityIdentityStore().resolve(migrating: $0) }
    }

    func resolve(_ body: Any, source: URL?, frame: WebFrameSource) throws -> String {
        guard let source = frame.matchingPageURL(source),
              let origin = WebAddressPolicy.origin(entry), WebAddressPolicy.origin(source) == origin,
              source.path == entry.path || (source.path.isEmpty && entry.path == "/") || (source.path == "/" && entry.path.isEmpty),
              let fields = body as? [String: Any], Set(fields.keys) == ["installation"] else {
            throw WebIntegrationError.addressDenied
        }
        let candidate: String?
        if fields["installation"] is NSNull { candidate = nil }
        else if let value = fields["installation"] as? String, WebActivityIdentityStore.isValid(value) { candidate = value }
        else { throw WebIntegrationError.invalidMessage }
        let value = try resolveID(candidate)
        guard WebActivityIdentityStore.isValid(value) else { throw WebIntegrationError.unavailable }
        return value
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
        guard let browser, message.webView === browser else { replyHandler(nil, "Identity unavailable"); return }
        let origin = message.frameInfo.securityOrigin
        let frame = WebFrameSource(mainFrame: message.frameInfo.isMainFrame,
            scheme: origin.protocol, host: origin.host, port: origin.port)
        do {
            let value = try resolve(message.body, source: message.frameInfo.request.url, frame: frame)
            #if DEBUG
            print("[H5-Identity] migration_ready")
            #endif
            replyHandler(value, nil)
        } catch {
            #if DEBUG
            print("[H5-Identity] migration_failed")
            #endif
            replyHandler(nil, "Identity unavailable")
        }
    }
}
