import Foundation

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
            #endif
            guard let entry = URL(string: IntegrationConstants.Activity.entry) else {
                throw WebIntegrationError.invalidConfiguration
            }
            return WebActivityEntryService(entry: entry)
        }
    }
}
