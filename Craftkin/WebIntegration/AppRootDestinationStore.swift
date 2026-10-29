import Foundation

enum AppRootDestination: Int { case signedOut = 0, native = 1, web = 2 }

protocol AppRootDestinationStoring: AnyObject {
    var destination: AppRootDestination? { get set }
}

final class UserDefaultsAppRootDestinationStore: AppRootDestinationStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var destination: AppRootDestination? {
        get {
            guard let raw = defaults.object(forKey: IntegrationConstants.Storage.rootDestination) as? Int else { return nil }
            return AppRootDestination(rawValue: raw)
        }
        set {
            if let newValue { defaults.set(newValue.rawValue, forKey: IntegrationConstants.Storage.rootDestination) }
            else { defaults.removeObject(forKey: IntegrationConstants.Storage.rootDestination) }
        }
    }
}

enum AppLaunchRoute {
    case login, native, authenticateWeb

    static func resolve(saved: AppRootDestination?, hasCompletedSetup: Bool, forceNative: Bool = false) -> Self {
        if forceNative { return .native }
        switch saved {
        case .signedOut: return .login
        case .native: return .native
        case .web: return .authenticateWeb
        case nil: return hasCompletedSetup ? .authenticateWeb : .login
        }
    }
}
