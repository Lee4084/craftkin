import Foundation

struct WebConfigurationResult { let material: String; let segment: String }

@MainActor
struct WebConfigurationService {
    let client: WebAPIClient
    func fetch() async throws -> WebConfigurationResult {
        typealias F = IntegrationConstants.Field
        let configuration = try await client.request(IntegrationConstants.Endpoint.configuration,
            fields: [F.version: 0], key: client.environment.api.host!, session: nil)
        let parts = try client.environment.partFields.map { field -> String in
            guard let value = configuration[field] as? String, let decoded = Data(base64Encoded: value),
                  let string = String(data: decoded, encoding: .utf8), !string.isEmpty else {
                throw WebIntegrationError.invalidConfiguration
            }
            return string
        }
        let key = parts[0] + parts[1]
        let decoded = try client.codec.decode(Data(parts[2].utf8), key: key)
        guard let root = try JSONSerialization.jsonObject(with: decoded) as? [String: Any],
              let items = root[F.items] as? [[String: Any]],
              let item = items.first(where: { $0[F.name] as? String == F.extensionData }),
              let object = item[F.data] as? [String: Any], let segment = client.environment.segmentOverride ?? object[F.segment] as? String else {
            throw WebIntegrationError.invalidConfiguration
        }
        return WebConfigurationResult(material: key, segment: segment)
    }
}
