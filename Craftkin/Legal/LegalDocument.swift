import Foundation

nonisolated enum LegalDocument: String, CaseIterable, Identifiable {
    case terms, privacy
    var id: String { rawValue }
    var title: String { self == .terms ? "Terms of Service" : "Privacy Policy" }
    static let startupURL = URL(string: "https://craftkin.pages.dev")!
    static let contactEmail = "EchoSkillContact@outlook.com"
    static var contactURL: URL { URL(string: "mailto:" + contactEmail)! }
    var url: URL { URL(string: "/" + rawValue, relativeTo: Self.startupURL)!.absoluteURL }
}
