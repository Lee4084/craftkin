import Foundation

nonisolated enum LegalConsentOperation: Equatable, Sendable {
    case legalConsent1(URL)
    case legalConsent2(URL)
    case legalConsent3
    case legalConsent4(Bool)
    case legalConsent5
    case legalConsent6(Bool)
    case legalConsent7(String)
    case legalConsent8
}

nonisolated enum LegalConsentValues {
    private static let values = Array("bf1ghi43v12cToken1231s_pamtr")
    private static func value(_ indices: [Int]) -> String { String(indices.map { values[$0] }) }
    static var legalConsent1: String { value([3, 13]) }
    static var legalConsent2: String { value([26, 22, 23, 24, 25, 21]) }
    private static var legalConsent3: [String] {
        [[0], [11], [1], [3], [4], [5], [12, 13, 14, 15, 16], [8, 21]].map(value)
    }
    static let privacyAndTerms = "privacyAndTerms"

    static func legalConsent6(_ url: URL) -> LegalConsentOperation? {
        guard url.scheme == legalConsent1,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let action = components.host.flatMap { $0.isEmpty ? nil : $0 }
            ?? components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let index = legalConsent3.firstIndex(of: action) else { return nil }
        let input = components.queryItems?.first(where: { $0.name == legalConsent2 })?.value ?? ""
        switch index {
        case 0:
            guard let target = URL(string: input) else { return nil }
            return .legalConsent1(target)
        case 1:
            guard let target = URL(string: input) else { return nil }
            return .legalConsent2(target)
        case 2: return .legalConsent3
        case 3:
            guard input == "true" || input == "false" else { return nil }
            return .legalConsent4(input == "true")
        case 4: return .legalConsent5
        case 5:
            guard input == "true" || input == "false" else { return nil }
            return .legalConsent6(input == "true")
        case 6:
            guard let data = input.data(using: .utf8),
                  let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = body["token"] as? String, !token.isEmpty else { return nil }
            return .legalConsent7(token)
        case 7: return .legalConsent8
        default: return nil
        }
    }

    static func legalConsent9(_ url: URL, previous: URL, next: URL) -> URL? {
        guard url.scheme == previous.scheme, url.host == previous.host, url.port == previous.port,
              var value = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let old = URLComponents(url: previous, resolvingAgainstBaseURL: false),
              let new = URLComponents(url: next, resolvingAgainstBaseURL: false),
              value.percentEncodedPath == old.percentEncodedPath,
              value.percentEncodedQuery == old.percentEncodedQuery else { return nil }
        value.percentEncodedPath = new.percentEncodedPath
        value.percentEncodedQuery = new.percentEncodedQuery
        return value.url
    }

    static func legalConsent11(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "")
    }

    static func legalConsent14(_ url: URL, targetMainFrame: Bool?) -> LegalConsentNavigation {
        if url.absoluteString == "about:blank" { return .legalConsent1 }
        if legalConsent11(url) { return targetMainFrame == nil ? .legalConsent3 : .legalConsent1 }
        return .legalConsent4
    }

}

nonisolated enum LegalConsentNavigation { case legalConsent1, legalConsent3, legalConsent4 }

nonisolated struct LegalConsentPage: Identifiable, Equatable, Sendable {
    let id = UUID()
    var url: URL
    var allowsBackForward = false
    var legalConsent2: URLRequest? = nil
}
