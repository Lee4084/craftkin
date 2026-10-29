import Foundation

enum OnboardingStep: Equatable {
    case welcome
    case howItWorks
    case privacy
    case familySpaceChoice
    case createFamilySpace
    case joinFamilySpace
    case complete
}

enum OnboardingCompletion: Codable, Equatable {
    case localOnly
    case familySpaceCreated(name: String)
    case familySpaceJoined(name: String)

    var title: String {
        switch self {
        case .localOnly:
            "Your private library is ready."
        case .familySpaceCreated:
            "Your Family Space is ready."
        case .familySpaceJoined:
            "You're part of the family."
        }
    }

    var spaceName: String? {
        switch self {
        case .localOnly:
            nil
        case let .familySpaceCreated(name), let .familySpaceJoined(name):
            name
        }
    }
}

enum FamilySpaceNameError: Error, Equatable {
    case required
    case tooLong(maximum: Int)

    var message: String {
        switch self {
        case .required:
            "Enter a name for your Family Space."
        case let .tooLong(maximum):
            "Keep the name to \(maximum) characters or fewer."
        }
    }
}

enum FamilySpaceNameValidationResult: Equatable {
    case valid(String)
    case invalid(FamilySpaceNameError)
}

enum FamilySpaceNameValidator {
    static let maximumLength = 40

    static func validate(_ rawName: String) -> FamilySpaceNameValidationResult {
        let normalized = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .invalid(.required) }
        guard normalized.count <= maximumLength else {
            return .invalid(.tooLong(maximum: maximumLength))
        }
        return .valid(normalized)
    }
}

struct InviteCode: Codable, Equatable, Hashable {
    let value: String

    init?(rawValue: String) {
        let normalized = rawValue
            .filter { $0 != " " && $0 != "-" }
            .uppercased()

        guard normalized.count == 6,
              normalized.unicodeScalars.allSatisfy({ scalar in
                  CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII
              }) else {
            return nil
        }
        value = normalized
    }
}

struct InvitationPreview: Equatable {
    let code: InviteCode
    let familyName: String
    let memberCount: Int
    let skillCount: Int
    let organizerName: String
}

enum LocalInvitationValidator {
    static func preview(for rawCode: String) -> InvitationPreview? {
        guard let code = InviteCode(rawValue: rawCode), code.value == "ECHO26" else {
            return nil
        }
        return InvitationPreview(
            code: code,
            familyName: "The Carter Family",
            memberCount: 4,
            skillCount: 18,
            organizerName: "Emma"
        )
    }
}

enum OnboardingError: Error, LocalizedError {
    case invalidFamilySpaceName(FamilySpaceNameError)

    var errorDescription: String? {
        switch self {
        case let .invalidFamilySpaceName(error):
            error.message
        }
    }
}

