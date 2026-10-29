import Foundation

enum WebBridgeCommand: Equatable {
    case endSession, internalPage(URL), externalPage(URL), event(Data), transaction(Data)
    case settings, keepAwake(Bool), close, history(Bool), contact, ignored

    var actionID: String {
        typealias B = IntegrationConstants.Bridge
        switch self {
        case .endSession: return B.endSession
        case .internalPage: return B.internalPage
        case .externalPage: return B.externalPage
        case .event: return B.event
        case .transaction: return B.transaction
        case .settings: return B.settings
        case .keepAwake: return B.awake
        case .close: return B.close
        case .history: return B.history
        case .contact: return B.contact
        case .ignored: return IntegrationConstants.Diagnostic.unknownAction
        }
    }
}

enum WebBridgeAvailability { case hidden, loading, ready }

struct WebFrameSource {
    let mainFrame: Bool
    let scheme: String
    let host: String
    let port: Int

    static let unavailable = WebFrameSource(mainFrame: false, scheme: "", host: "", port: 0)

    func trustedPageURL(_ document: URL?, policy: WebAddressPolicy) -> URL? {
        guard let document = matchingPageURL(document), policy.allows(document) else { return nil }
        return document
    }

    func matchingPageURL(_ document: URL?) -> URL? {
        guard mainFrame, let document, WebBrowserAddress.isWebURL(document),
              scheme.lowercased() == document.scheme?.lowercased(),
              host.lowercased() == document.host?.lowercased() else { return nil }
        let defaultPort = scheme.lowercased() == IntegrationConstants.Route.secure ? 443 : 80
        guard (port == 0 ? defaultPort : port) == (document.port ?? defaultPort) else { return nil }
        return document
    }
}

enum WebBrowserAddress {
    static func isWebURL(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme?.lowercased(),
              [IntegrationConstants.Route.secure, IntegrationConstants.Route.plain].contains(scheme),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              parts.port.map({ (1...65535).contains($0) }) ?? true else { return false }
        return true
    }

    static func isApplicationURL(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme?.lowercased(), !scheme.isEmpty,
              ![IntegrationConstants.Route.secure, IntegrationConstants.Route.plain].contains(scheme),
              !IntegrationConstants.Route.blockedSchemes.contains(scheme),
              parts.user == nil, parts.password == nil, parts.port == nil else { return false }
        return true
    }
}

enum WebLinkDestination: Equatable {
    case page(URL), browser(URL), system(URL)
}

enum WebNavigationDecision: Equatable {
    case allow, cancel, deny, open(WebLinkDestination)
}

struct WebLinkRouter {
    let policy: WebAddressPolicy

    func navigation(to url: URL, source: URL?, sourceMainFrame: Bool, targetMainFrame: Bool?,
                    userActivated: Bool, active: Bool, initialDocument: URL? = nil) -> WebNavigationDecision {
        let activeSource = active && sourceMainFrame && source.map(WebBrowserAddress.isWebURL) == true
        if WebBrowserAddress.isWebURL(url) {
            if targetMainFrame == nil, !activeSource, !policy.allows(url), url != initialDocument { return .cancel }
            return .allow
        }
        if url.absoluteString == IntegrationConstants.Route.blank {
            return targetMainFrame != nil || activeSource || url == initialDocument ? .allow : .cancel
        }
        guard targetMainFrame != false else { return .cancel }
        guard activeSource, WebBrowserAddress.isApplicationURL(url) else { return .deny }
        return .open(.system(url))
    }

    func destination(for command: WebBridgeCommand) throws -> WebLinkDestination {
        switch command {
        case .internalPage(let url):
            guard WebBrowserAddress.isWebURL(url) else { throw WebIntegrationError.addressDenied }
            return policy.allows(url) ? .page(url) : .browser(url)
        case .externalPage(let url):
            guard WebBrowserAddress.isWebURL(url) || WebBrowserAddress.isApplicationURL(url) else { throw WebIntegrationError.addressDenied }
            return .system(url)
        default: throw WebIntegrationError.unsupported
        }
    }
}

struct WebBridgeParser {
    let policy: WebAddressPolicy

    static func actionID(for url: URL) -> String {
        typealias B = IntegrationConstants.Bridge
        guard url.scheme == B.scheme, let action = url.host, B.actions.contains(action) else {
            return IntegrationConstants.Diagnostic.unknownAction
        }
        return action
    }

    func parse(_ url: URL, source: URL?, mainFrame: Bool,
               availability: WebBridgeAvailability = .ready) throws -> WebBridgeCommand {
        guard mainFrame, let source, policy.allows(source) else { throw WebIntegrationError.addressDenied }
        return try decode(url, availability: availability)
    }

    func parseBrowser(_ url: URL, source: URL?, mainFrame: Bool,
                      availability: WebBridgeAvailability = .ready) throws -> WebBridgeCommand {
        guard mainFrame, let source, WebBrowserAddress.isWebURL(source) else { throw WebIntegrationError.addressDenied }
        let command = try decode(url, availability: availability)
        switch command {
        case .internalPage, .externalPage, .close, .history, .keepAwake, .ignored: return command
        default: throw WebIntegrationError.addressDenied
        }
    }

    private func decode(_ url: URL, availability: WebBridgeAvailability) throws -> WebBridgeCommand {
        typealias B = IntegrationConstants.Bridge
        guard url.absoluteString.utf8.count <= IntegrationConstants.Limit.message,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.scheme == B.scheme,
              parts.user == nil, parts.password == nil, parts.port == nil, parts.path.isEmpty, parts.fragment == nil else {
            throw WebIntegrationError.invalidMessage
        }
        let items = parts.queryItems ?? []
        guard items.count <= 1, items.allSatisfy({ $0.name == B.argument }) else { throw WebIntegrationError.invalidMessage }
        // The reference protocol ignores unrecognized actions without executing a capability.
        guard let action = parts.host, B.actions.contains(action) else { return .ignored }
        let argument = items.first?.value ?? ""
        func link(external: Bool = false) throws -> URL {
            guard let url = URL(string: argument), WebBrowserAddress.isWebURL(url)
                    || (external && WebBrowserAddress.isApplicationURL(url)) else { throw WebIntegrationError.invalidMessage }
            return url
        }
        func flag() throws -> Bool {
            guard [B.yes, B.no].contains(argument) else { throw WebIntegrationError.invalidMessage }
            return argument == B.yes
        }
        func object() throws -> Data {
            let data = Data(argument.utf8)
            guard (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { throw WebIntegrationError.invalidMessage }
            return data
        }
        if availability == .hidden {
            if action == B.awake { return try flag() ? .ignored : .keepAwake(false) }
            throw WebIntegrationError.unsupported
        }
        switch action {
        case B.internalPage: return .internalPage(try link())
        case B.externalPage: return .externalPage(try link(external: true))
        case B.awake: return .keepAwake(try flag())
        case B.history: return .history(try flag())
        case B.event: return .event(try object())
        case B.transaction: return .transaction(try object())
        default:
            guard argument.isEmpty else { throw WebIntegrationError.invalidMessage }
            switch action {
            case B.endSession: return .endSession
            case B.settings: return .settings
            case B.close: return .close
            case B.contact: return .contact
            default: return .ignored
            }
        }
    }
}

@MainActor
protocol WebOptionalCapabilities { func perform(_ command: WebBridgeCommand) async throws }

@MainActor
struct WebDisabledCapabilities: WebOptionalCapabilities {
    func perform(_ command: WebBridgeCommand) async throws { throw WebIntegrationError.unsupported }
}
