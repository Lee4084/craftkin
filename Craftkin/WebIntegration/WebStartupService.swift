import Foundation

@MainActor
// A nil session explicitly selects the native destination.
protocol WebSessionPreparing { func prepare() async throws -> WebPreparedSession? }

@MainActor
final class WebStartupService: WebSessionPreparing {
    private let client: WebAPIClient
    init(environment: WebEnvironment, transport: any WebTransport, codec: any WebCodec, identity: WebClientIdentity) {
        client = WebAPIClient(environment: environment, transport: transport, codec: codec, identity: identity)
    }

    func prepare() async throws -> WebPreparedSession? {
        let configuration = try await step(.configuration) { try await WebConfigurationService(client: client).fetch() }
        let session = try await step(.authentication) { try await WebIdentityService(client: client).establish(key: configuration.material) }
        guard let services = try await step(.directory, operation: { try await WebServiceDirectory(client: client).fetch(key: configuration.material, session: session) }) else {
            try Task.checkCancellation()
            return nil
        }
        return try await step(.entry) {
            let environment = try client.environment.selecting(web: services.web)
            let entry = try WebEntryBuilder(codec: client.codec).build(environment: environment, session: session,
                services: services, segment: configuration.segment, identity: client.identity)
            try Task.checkCancellation()
            return WebPreparedSession(entry: entry, session: session, services: services, environment: environment)
        }
    }

    private func step<T>(_ stage: WebStartupStage, operation: () async throws -> T) async throws -> T {
        do { return try await operation() }
        catch is CancellationError { throw CancellationError() }
        catch { throw WebStartupFailure(stage: stage, error: error) }
    }
}
