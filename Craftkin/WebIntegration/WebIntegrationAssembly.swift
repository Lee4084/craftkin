import Foundation
import UIKit

@MainActor
enum WebIntegrationAssembly {
    static func coordinator() -> WebIntegrationCoordinator {
        WebIntegrationCoordinator {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains(IntegrationConstants.Configuration.testingArgument),
               arguments.contains(IntegrationConstants.Configuration.disabledArgument) {
                throw WebIntegrationError.unavailable
            }
            if arguments.contains(IntegrationConstants.Configuration.testingArgument),
               arguments.contains(IntegrationConstants.Configuration.nativeTestingArgument) {
                return WebNativeTestService()
            }
            #endif
            var values = IntegrationConstants.environmentValues
            guard !values.isEmpty else { throw WebIntegrationError.unavailable }
            let store = WebSecureStore()
            let cached = try store.read(IntegrationConstants.Storage.entryMaterial)
            var supplied: String?
            #if DEBUG
            supplied = ProcessInfo.processInfo.environment[IntegrationConstants.Configuration.debugMaterial]
            #endif
            let material = try WebEntryMaterialResolver.resolve(override: supplied, cached: cached) {
                try store.write($0, account: IntegrationConstants.Storage.entryMaterial)
            }
            values[IntegrationConstants.Configuration.entryKey] = material
            let environment = try WebEnvironment(values: values)
            #if !DEBUG
            guard environment.name == IntegrationConstants.Configuration.production else { throw WebIntegrationError.invalidConfiguration }
            #endif
            let identity = WebClientIdentity(installation: try store.installationID(), bundle: Bundle.main.bundleIdentifier ?? "",
                version: Bundle.main.object(forInfoDictionaryKey: IntegrationConstants.BundleKey.version) as? String ?? "",
                name: Bundle.main.object(forInfoDictionaryKey: IntegrationConstants.BundleKey.displayName) as? String
                    ?? Bundle.main.object(forInfoDictionaryKey: IntegrationConstants.BundleKey.name) as? String ?? "",
                model: UIDevice.current.model, system: UIDevice.current.systemVersion,
                language: Locale.current.language.languageCode?.identifier ?? IntegrationConstants.Header.defaultLanguage,
                region: Locale.current.region?.identifier ?? "", zone: TimeZone.current.identifier, locale: Locale.current.identifier)
            return WebStartupService(environment: environment, transport: WebURLTransport(), codec: WebCompatibilityCodec(), identity: identity)
        }
    }
}

#if DEBUG
@MainActor
private struct WebNativeTestService: WebSessionPreparing {
    func prepare() async throws -> WebPreparedSession? { nil }
}
#endif
