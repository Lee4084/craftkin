import Foundation

struct WebEntryBuilder {
    let codec: any WebCodec
    func build(environment: WebEnvironment, session: WebSession, services: WebRemoteServices,
               segment: String, identity: WebClientIdentity) throws -> URL {
        guard environment.entryKey.utf8.count == 32 else { throw WebIntegrationError.missingEntryMaterial }
        guard !segment.isEmpty, segment.count <= 80,
              segment.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")).contains($0) }),
              segment.allSatisfy(\.isASCII) else { throw WebIntegrationError.invalidConfiguration }
        typealias F = IntegrationConstants.ShortField
        func trailing(_ url: URL?) -> String {
            guard let url else { return "" }
            return url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/"
        }
        let fields = [F.installation: identity.installation, F.credential: session.credential,
                      F.bundle: identity.bundle, F.api: trailing(environment.api), F.messaging: trailing(services.messaging),
                      F.events: trailing(services.events), F.terms: environment.terms?.absoluteString ?? "",
                      F.privacy: environment.privacy?.absoluteString ?? "", F.version: identity.version, F.name: identity.name,
                      F.partOne: environment.partFields[0], F.partTwo: environment.partFields[1], F.partThree: environment.partFields[2]]
        let encrypted = try codec.encode(JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]), key: environment.entryKey)
        guard let query = String(data: encrypted, encoding: .utf8), !query.isEmpty,
              Data(base64Encoded: query) != nil else { throw WebIntegrationError.encoding }
        let base = services.web.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + IntegrationConstants.Route.base + segment + "/?" + query + IntegrationConstants.Route.fragment),
              environment.webPolicy.allows(url) else { throw WebIntegrationError.addressDenied }
        return url
    }
}
