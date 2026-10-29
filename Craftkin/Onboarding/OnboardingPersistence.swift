import Foundation

protocol OnboardingCompletionStoring: AnyObject {
    var completion: OnboardingCompletion? { get set }
}

final class InMemoryOnboardingCompletionStore: OnboardingCompletionStoring {
    var completion: OnboardingCompletion?

    init(completion: OnboardingCompletion? = nil) {
        self.completion = completion
    }
}

final class UserDefaultsOnboardingCompletionStore: OnboardingCompletionStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "echoskill.onboarding.completion") {
        self.defaults = defaults
        self.key = key
    }

    var completion: OnboardingCompletion? {
        get {
            guard let data = defaults.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(OnboardingCompletion.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                defaults.removeObject(forKey: key)
                return
            }
            defaults.set(data, forKey: key)
        }
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}

