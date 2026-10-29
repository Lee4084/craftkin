import Foundation

enum LibraryFixtureState: String, Equatable {
    case empty
    case populated

    static func launchState(arguments: [String]) -> Self {
        guard let index = arguments.firstIndex(of: "-libraryFixture"),
              arguments.indices.contains(index + 1),
              let requested = Self(rawValue: arguments[index + 1]) else {
            return .populated
        }
        return requested
    }
}

enum SkillProgress: String, CaseIterable, Codable, Hashable {
    case new
    case inProgress
    case completed
    case saved
}

enum LibrarySort: String, CaseIterable, Codable, Hashable {
    case recentlyAdded
    case alphabetical
    case recentlyLearned
    case makerName

    var title: String {
        switch self {
        case .recentlyAdded: "Recently Added"
        case .alphabetical: "Alphabetical"
        case .recentlyLearned: "Recently Learned"
        case .makerName: "Maker Name"
        }
    }
}

struct FamilyMaker: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let relation: String
    let imageName: String
    let roles: String
    let quote: String
    let story: String
}

struct LessonStep: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let minutes: Int
    let isComplete: Bool
}

struct SkillLesson: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let category: String
    let maker: FamilyMaker
    let coverImageName: String
    let stepCount: Int
    let durationMinutes: Int
    let completedSteps: Int
    let progress: SkillProgress
    let materials: [String]
    let tools: [String]
    let transcript: String
    let steps: [LessonStep]
    let addedOrder: Int
    let learnedOrder: Int

    var searchableText: String {
        ([title, category, maker.name, maker.relation, transcript]
            + materials
            + tools
            + steps.map(\.title))
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}

struct LibraryFilter: Equatable {
    var makerIDs: Set<String> = []
    var categories: Set<String> = []
    var progress: SkillProgress?
    var sort: LibrarySort = .recentlyAdded

    var activeCount: Int {
        makerIDs.count + categories.count + (progress == nil ? 0 : 1)
    }
}

enum LibraryRoute: Equatable {
    case home
    case allSkills
    case search
    case skillDetail(String)
    case makerProfile(String)
}

enum LibraryQueryEngine {
    static func search(_ skills: [SkillLesson], for rawQuery: String) -> [SkillLesson] {
        let query = rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        guard !query.isEmpty else { return skills }
        return skills.filter { $0.searchableText.contains(query) }
    }

    static func apply(_ filter: LibraryFilter, to skills: [SkillLesson]) -> [SkillLesson] {
        let filtered = skills.filter { skill in
            (filter.makerIDs.isEmpty || filter.makerIDs.contains(skill.maker.id))
                && (filter.categories.isEmpty || filter.categories.contains(skill.category))
                && (filter.progress == nil || filter.progress == skill.progress)
        }

        switch filter.sort {
        case .recentlyAdded:
            return filtered.sorted { $0.addedOrder > $1.addedOrder }
        case .alphabetical:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .recentlyLearned:
            return filtered.sorted { $0.learnedOrder > $1.learnedOrder }
        case .makerName:
            return filtered.sorted {
                if $0.maker.name == $1.maker.name { return $0.title < $1.title }
                return $0.maker.name < $1.maker.name
            }
        }
    }
}
