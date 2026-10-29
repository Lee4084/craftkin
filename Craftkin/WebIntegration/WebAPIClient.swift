import Foundation

@MainActor
struct WebAPIClient {
    let environment: WebEnvironment
    let transport: any WebTransport
    let codec: any WebCodec
    let identity: WebClientIdentity
    var traceOutput: (String) -> Void = WebRequestTrace.debugOutput

    func request(_ path: String, fields: [String: Any], key: String, session: WebSession?) async throws -> [String: Any] {
        try Task.checkCancellation()
        guard let url = URL(string: path, relativeTo: environment.api)?.absoluteURL,
              WebAddressPolicy.origin(url) == WebAddressPolicy.origin(environment.api) else { throw WebIntegrationError.addressDenied }
        let stage: WebStartupStage
        switch path {
        case IntegrationConstants.Endpoint.configuration: stage = .configuration
        case IntegrationConstants.Endpoint.session: stage = .authentication
        case IntegrationConstants.Endpoint.services: stage = .directory
        default: stage = .setup
        }
        let trace = WebRequestTrace(stage: stage, url: url, installationID: identity.installation, userID: session?.userID)
        trace.emit(.start, output: traceOutput)
        do {
            var body = fields
            body[IntegrationConstants.Field.headers] = headers(session: session)
            var request = URLRequest(url: url, timeoutInterval: IntegrationConstants.Limit.request)
            request.httpMethod = IntegrationConstants.Header.method
            request.setValue(IntegrationConstants.Header.contentValue, forHTTPHeaderField: IntegrationConstants.Header.contentType)
            request.httpBody = try codec.encode(JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]), key: key)
            let encoded = try await transport.send(request)
            try Task.checkCancellation()
            let object = try WebResponse.object(codec.decode(encoded, key: key))
            let returnedUser = (object[IntegrationConstants.Field.userInfo] as? [String: Any])?[IntegrationConstants.Field.user] as? String
            trace.emit(.success, userID: session?.userID ?? returnedUser, output: traceOutput)
            return object
        } catch is CancellationError {
            trace.emit(.cancelled, output: traceOutput)
            throw CancellationError()
        } catch {
            trace.emit(.failure, error: error, output: traceOutput)
            throw error
        }
    }

    private func headers(session: WebSession?) -> [String: String] {
        typealias H = IntegrationConstants.Header
        return [H.installation: identity.installation, H.language: identity.language, H.deviceLanguage: identity.language,
                H.systemLanguage: identity.language, H.model: identity.model, H.zone: identity.zone, H.region: identity.region,
                H.system: identity.system, H.locale: identity.locale, H.user: session?.userID ?? "",
                IntegrationConstants.Field.version: identity.version, H.bundle: identity.bundle,
                H.authorization: session.map { H.bearer + $0.credential } ?? "",
                H.anchor: IntegrationConstants.Bridge.no, H.platform: H.platformValue, H.revision: H.zero]
    }

}
