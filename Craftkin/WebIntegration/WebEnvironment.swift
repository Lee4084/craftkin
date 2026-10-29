import Foundation

enum WebIntegrationError: Error, Equatable {
    case unavailable, invalidConfiguration, malformedResponse, encoding, network, offline, expired, addressDenied, unsupported, invalidMessage, missingEntryMaterial, servicesUnavailable, emptyPage
}

struct WebAddressPolicy {
    let origins: Set<String>
    let pathPrefixes: [String]

    init(origins: [String], pathPrefixes: [String] = [IntegrationConstants.Route.root]) throws {
        guard !origins.isEmpty, !pathPrefixes.isEmpty,
              pathPrefixes.allSatisfy({ $0.hasPrefix("/") && $0.hasSuffix("/") && !$0.contains("..") && !$0.contains("%") }) else {
            throw WebIntegrationError.invalidConfiguration
        }
        self.origins = try Set(origins.map { value in
            guard let url = URL(string: value), let origin = Self.origin(url),
                  url.path.isEmpty || url.path == IntegrationConstants.Route.root,
                  url.query == nil, url.fragment == nil else { throw WebIntegrationError.invalidConfiguration }
            return origin
        })
        self.pathPrefixes = pathPrefixes
    }

    static func origin(_ url: URL) -> String? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == IntegrationConstants.Route.secure,
              let host = parts.host?.lowercased(), !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443 else { return nil }
        return IntegrationConstants.Route.secure + "://" + host
    }

    func allows(_ url: URL) -> Bool {
        guard let origin = Self.origin(url), origins.contains(origin),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let encoded = parts.percentEncodedPath.lowercased()
        guard !encoded.contains("%2e"), !encoded.contains("%2f"), !encoded.contains("%5c"), !encoded.contains("%25"),
              !parts.path.contains("\\"), !parts.path.split(separator: "/").contains("..") else { return false }
        let path = parts.path.isEmpty ? IntegrationConstants.Route.root : parts.path
        return pathPrefixes.contains { path.hasPrefix($0) }
    }
}

struct WebEnvironment {
    let name: String
    let api: URL
    private(set) var webPolicy: WebAddressPolicy
    let trustedRoot: String?
    let externalPolicy: WebAddressPolicy?
    let serviceOrigins: Set<String>
    let messaging: URL?
    let events: URL?
    let terms: URL?
    let privacy: URL?
    let partFields: [String]
    let entryKey: String
    let segmentOverride: String?

    init(values: [String: Any]) throws {
        typealias C = IntegrationConstants.Configuration
        guard !values.isEmpty else { throw WebIntegrationError.unavailable }
        guard values[C.confirmed] as? Bool == true,
              let name = values[C.environment] as? String, [C.test, C.production].contains(name),
              let apiValue = values[C.api] as? String, let api = URL(string: apiValue),
              let origins = values[C.origins] as? [String], let paths = values[C.paths] as? [String],
              let external = values[C.externalOrigins] as? [String],
              let services = values[C.serviceOrigins] as? [String],
              let fields = values[C.partFields] as? [String], fields.count == 3, Set(fields).count == 3,
              fields.allSatisfy({ !$0.isEmpty && $0.utf8.count < 128 }),
              fields.allSatisfy({ $0.allSatisfy(\.isASCII) }) else {
            throw WebIntegrationError.invalidConfiguration
        }
        _ = try WebAddressPolicy(origins: [apiValue])
        let externalPolicy = external.isEmpty ? nil : try WebAddressPolicy(origins: external)
        func legal(_ field: String) throws -> URL? {
            guard let raw = values[field] as? String, !raw.isEmpty else { return nil }
            guard let url = URL(string: raw), externalPolicy?.allows(url) == true else {
                throw WebIntegrationError.invalidConfiguration
            }
            return url
        }
        let root = (values[C.trustedRoot] as? String)?.lowercased()
        if let root {
            guard root.split(separator: ".").count >= 2,
                  let url = URL(string: IntegrationConstants.Route.secure + "://" + root),
                  WebAddressPolicy.origin(url) != nil, url.host == root, url.path.isEmpty, url.query == nil, url.fragment == nil else {
                throw WebIntegrationError.invalidConfiguration
            }
        }
        guard !origins.isEmpty || root != nil else {
            throw WebIntegrationError.invalidConfiguration
        }
        let key = values[C.entryKey] as? String ?? ""
        guard key.isEmpty || (key.utf8.count == 32 && key.allSatisfy(\.isASCII)) else { throw WebIntegrationError.invalidConfiguration }
        self.name = name
        self.api = api
        self.trustedRoot = root
        self.webPolicy = try WebAddressPolicy(origins: origins.isEmpty ? [IntegrationConstants.Route.secure + "://" + root!] : origins, pathPrefixes: paths)
        self.externalPolicy = externalPolicy
        let serviceOrigins = try Set(services.map { value in
            guard let url = URL(string: value), let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  [IntegrationConstants.Route.secure, IntegrationConstants.Route.socket].contains(components.scheme ?? ""),
                  components.host != nil, components.user == nil, components.password == nil,
                  components.port == nil || components.port == 443,
                  components.path.isEmpty || components.path == "/", components.query == nil, components.fragment == nil else {
                throw WebIntegrationError.invalidConfiguration
            }
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        })
        self.serviceOrigins = serviceOrigins
        func configuredService(_ field: String) throws -> URL? {
            guard let value = values[field] as? String, !value.isEmpty else { return nil }
            guard let url = URL(string: value), let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let scheme = parts.scheme?.lowercased(), let host = parts.host?.lowercased(),
                  parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443,
                  parts.path.isEmpty || parts.path == "/", parts.query == nil, parts.fragment == nil,
                  serviceOrigins.contains(scheme + "://" + host) else { throw WebIntegrationError.invalidConfiguration }
            return url
        }
        self.messaging = try configuredService(C.messaging)
        self.events = try configuredService(C.events)
        self.terms = try legal(C.terms)
        self.privacy = try legal(C.privacy)
        self.partFields = fields
        self.entryKey = key
        self.segmentOverride = values[C.segmentOverride] as? String
    }

    func selecting(web: URL) throws -> Self {
        guard let origin = WebAddressPolicy.origin(web), web.path.isEmpty || web.path == "/",
              web.query == nil, web.fragment == nil, let host = web.host?.lowercased() else {
            throw WebIntegrationError.addressDenied
        }
        let explicitlyAllowed = webPolicy.origins.contains(origin)
        let withinRoot = trustedRoot.map { host.hasSuffix("." + $0) } ?? false
        guard explicitlyAllowed || withinRoot else { throw WebIntegrationError.addressDenied }
        var selected = self
        selected.webPolicy = try WebAddressPolicy(origins: [origin], pathPrefixes: webPolicy.pathPrefixes)
        return selected
    }
}

struct WebSession { let userID: String; let credential: String }
struct WebRemoteServices { let web: URL; let messaging: URL?; let events: URL?; let contactID: String? }
struct WebClientIdentity {
    let installation: String; let bundle: String; let version: String; let name: String
    let model: String; let system: String; let language: String; let region: String; let zone: String; let locale: String
}
struct WebPreparedSession {
    let entry: URL
    let session: WebSession
    let services: WebRemoteServices
    let environment: WebEnvironment
}
