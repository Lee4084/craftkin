import Foundation

@MainActor
struct WebIdentityService {
    let client: WebAPIClient
    func establish(key: String) async throws -> WebSession {
        typealias F = IntegrationConstants.Field
        let result = try await client.request(IntegrationConstants.Endpoint.session,
            fields: [F.token: client.identity.installation, F.authentication: 4], key: key, session: nil)
        guard let userInfo = result[F.userInfo] as? [String: Any],
              let user = userInfo[F.user] as? String, !user.isEmpty,
              let credential = result[F.token] as? String, !credential.isEmpty else {
            throw WebIntegrationError.malformedResponse
        }
        return WebSession(userID: user, credential: credential)
    }
}
