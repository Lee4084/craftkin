import Foundation
import CoreFoundation

@MainActor
struct WebServiceDirectory {
    let client: WebAPIClient
    private var environment: WebEnvironment { client.environment }
    func fetch(key: String, session: WebSession) async throws -> WebRemoteServices? {
        let object = try await client.request(IntegrationConstants.Endpoint.services, fields: [:], key: key, session: session)
        return try parse(object)
    }

    private func parse(_ object: [String: Any]) throws -> WebRemoteServices? {
        typealias F = IntegrationConstants.Field
        guard let flag = object[F.nativePage] as? NSNumber,
              CFGetTypeID(flag) == CFBooleanGetTypeID() else {
            throw WebIntegrationError.malformedResponse
        }
        // A native destination does not need H5 addresses or an encrypted entry.
        if flag.boolValue { return nil }
        let inner = object[F.data] as? [String: Any]
        let domains = inner?[F.domains] as? [Any] ?? []
        let summary = WebEndpointSummary(values: domains)
        guard let first = domains.first as? String, !first.isEmpty else {
            throw WebDirectoryFailure(reason: .servicesUnavailable, endpoints: summary)
        }
        guard let web = URL(string: first) else {
            throw WebDirectoryFailure(reason: .addressDenied, endpoints: summary)
        }
        do { _ = try environment.selecting(web: web) }
        catch { throw WebDirectoryFailure(reason: .addressDenied, endpoints: summary) }
        func optional(_ index: Int) -> URL? {
            guard domains.indices.contains(index), let value = domains[index] as? String, !value.isEmpty,
                  let url = URL(string: value), let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let scheme = parts.scheme?.lowercased(), let host = parts.host?.lowercased(),
                  parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443,
                  parts.query == nil, parts.fragment == nil, !parts.path.split(separator: "/").contains(".."),
                  !parts.percentEncodedPath.lowercased().contains("%2e"),
                  environment.serviceOrigins.contains(scheme + "://" + host) else { return nil }
            return url
        }
        return WebRemoteServices(web: web, messaging: environment.messaging ?? optional(1),
                                 events: environment.events ?? optional(2), contactID: object[F.contact] as? String)
    }
}
