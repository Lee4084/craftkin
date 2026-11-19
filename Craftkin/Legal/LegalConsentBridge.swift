import Foundation

nonisolated enum LegalConsentBridge {
    static let name = "legalConsent"

    static func acceptanceURL(for url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = components.queryItems?.filter { $0.name != "consent" } ?? []
        items.append(URLQueryItem(name: "consent", value: "app"))
        components.queryItems = items
        return components.url!
    }

    static func canReceiveMessage(from url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host?.lowercased() == LegalDocument.startupURL.host
            && (url.port == nil || url.port == 443) && url.user == nil && url.password == nil
    }

    static func canAccept(_ body: Any, from url: URL?, isMainFrame: Bool, hasLoaded: Bool) -> Bool {
        guard isMainFrame, hasLoaded, let url, canReceiveMessage(from: url),
              let message = body as? [String: String], message["action"] == "agree",
              message["version"] == LegalConsentStore.currentVersion,
              ["terms", "privacy", "terms.html", "privacy.html"].contains(url.lastPathComponent) else { return false }
        let modes = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.filter { $0.name == "consent" } ?? []
        return modes.count == 1 && modes[0].value == "app"
    }
}
