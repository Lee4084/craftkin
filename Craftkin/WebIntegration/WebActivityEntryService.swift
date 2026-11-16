import Foundation

/// Prepares the trusted H5 container and passes the Keychain identity; business routing stays in H5.
@MainActor
struct WebActivityEntryService: WebSessionPreparing {
    let entry: URL
    var readDeviceID: () throws -> String? = { try WebActivityIdentityStore().read() }

    func prepare() async throws -> WebPreparedSession? {
        try Task.checkCancellation()
        guard let origin = WebAddressPolicy.origin(entry), entry.query == nil,
              entry.fragment == nil, entry.path.isEmpty || entry.path == "/" else {
            throw WebIntegrationError.addressDenied
        }
        typealias C = IntegrationConstants.Configuration
        let environment = try WebEnvironment(values: [
            C.confirmed: true, C.environment: C.production, C.api: origin,
            C.origins: [origin, IntegrationConstants.Host.web], C.paths: ["/"], C.externalOrigins: [IntegrationConstants.Legal.origin],
            C.serviceOrigins: [], C.partFields: ["unused.one", "unused.two", "unused.three"]
        ])
        var address = URLComponents(url: entry, resolvingAgainstBaseURL: false)!
        if let deviceID = try readDeviceID() {
            guard WebActivityIdentityStore.isValid(deviceID) else { throw WebIntegrationError.unavailable }
            address.queryItems = [URLQueryItem(name: "deviceid", value: deviceID)]
            #if DEBUG
            print("[H5-Identity] keychain_ready_url_parameter")
            #endif
        }
        #if DEBUG
        if address.queryItems == nil { print("[H5-Identity] migration_required") }
        #endif
        guard let destination = address.url else { throw WebIntegrationError.addressDenied }
        return WebPreparedSession(entry: destination, session: WebSession(userID: "", credential: ""),
            services: WebRemoteServices(web: URL(string: origin)!, messaging: nil, events: nil, contactID: nil),
            environment: environment, isActivityEntry: true)
    }
}
