import Foundation

protocol AppNativeResumeStoring: AnyObject {
    var identity: String? { get set }
}

/// Remembers the last accepted native-container continuation, bound to the Keychain identity.
final class UserDefaultsAppNativeResumeStore: AppNativeResumeStoring {
    private let defaults: UserDefaults
    private let key = "activity.native.resume.identity.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var identity: String? {
        get { defaults.string(forKey: key) }
        set {
            if let newValue { defaults.set(newValue, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
    }
}
