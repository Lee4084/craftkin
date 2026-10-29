import Combine
import Foundation

@MainActor
final class LibraryCoordinator: ObservableObject {
    @Published var route: LibraryRoute = .home
    @Published var searchText = ""
    @Published var filter = LibraryFilter()
    @Published var unavailableFeature: String?

    @Published private(set) var skills: [SkillLesson]
    @Published private(set) var makers: [FamilyMaker]
    private var routeHistory: [LibraryRoute] = []
    @Published private(set) var makerMemories: [String: [String]] = [:]
    private let memoryStore: any MakerMemoryStoring

    init(repository: any SkillRepository, memoryStore: (any MakerMemoryStoring)? = nil) {
        self.memoryStore = memoryStore ?? UserDefaultsMakerMemoryStore()
        makerMemories = (try? self.memoryStore.load()) ?? [:]
        skills = repository.skills
        makers = repository.makers
    }

    func saveMemory(_ text: String, for makerID: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 2000 else { return false }
        var updated = makerMemories
        updated[makerID, default: []].append(normalized)
        do { try memoryStore.save(updated); makerMemories = updated; return true }
        catch { return false }
    }

    var visibleSkills: [SkillLesson] {
        LibraryQueryEngine.apply(filter, to: skills)
    }

    var searchResults: [SkillLesson] {
        LibraryQueryEngine.search(visibleSkills, for: searchText)
    }

    var categories: [String] {
        Array(Set(skills.map(\.category))).sorted()
    }

    var featuredSkill: SkillLesson? {
        skills.first { $0.progress == .inProgress } ?? skills.first
    }

    var backTitle: String {
        guard let destination = routeHistory.last else { return "Library" }
        switch destination {
        case .home: return "Library"
        case .allSkills: return "All Skills"
        case .search: return "Search"
        case .skillDetail: return "Lesson"
        case .makerProfile: return "Maker"
        }
    }

    func showAllSkills() { navigate(to: .allSkills) }
    func beginSearch() { navigate(to: .search) }
    func showSkill(_ id: String) { navigate(to: .skillDetail(id)) }
    func showMaker(_ id: String) { navigate(to: .makerProfile(id)) }

    func goHome() {
        routeHistory.removeAll()
        route = .home
    }

    func goBack() {
        guard let previousRoute = routeHistory.popLast() else { return }
        route = previousRoute
    }

    func skill(withID id: String) -> SkillLesson? {
        skills.first { $0.id == id }
    }

    func maker(withID id: String) -> FamilyMaker? {
        makers.first { $0.id == id }
    }

    func skills(for maker: FamilyMaker) -> [SkillLesson] {
        skills.filter { $0.maker.id == maker.id }
    }

    func apply(_ newFilter: LibraryFilter) { filter = newFilter }
    func clearFilters() { filter = LibraryFilter() }

    func clearSearch() {
        searchText = ""
        if routeHistory.last == .allSkills {
            goBack()
        } else {
            routeHistory.removeAll()
            route = .allSkills
        }
    }

    func explainLaterPhase(_ feature: String) {
        unavailableFeature = feature
    }

    func upsertPublishedDraft(_ draft: CaptureDraft) {
        guard let skill = IntegratedLessonFactory.librarySkill(from: draft) else { return }
        if let index = skills.firstIndex(where: { $0.id == skill.id }) {
            skills[index] = skill
        } else {
            skills.append(skill)
        }
        if !makers.contains(where: { $0.id == skill.maker.id }) {
            makers.append(skill.maker)
        }
    }

    func apply(_ progress: LearningProgress) {
        guard let index = skills.firstIndex(where: { $0.id == progress.lessonID }) else { return }
        let skill = skills[index]
        let state: SkillProgress = progress.lifecycle == .completed
            ? .completed
            : (progress.lifecycle == .ready ? .new : .inProgress)
        skills[index] = SkillLesson(
            id: skill.id,
            title: skill.title,
            category: skill.category,
            maker: skill.maker,
            coverImageName: skill.coverImageName,
            stepCount: skill.stepCount,
            durationMinutes: skill.durationMinutes,
            completedSteps: min(progress.completedStepIDs.count, skill.stepCount),
            progress: state,
            materials: skill.materials,
            tools: skill.tools,
            transcript: skill.transcript,
            steps: skill.steps,
            addedOrder: skill.addedOrder,
            learnedOrder: progress.lifecycle == .ready ? skill.learnedOrder : Int(progress.updatedAt.timeIntervalSince1970)
        )
    }

    func clearLearningProgress() {
        for skill in skills {
            let lesson = IntegratedLessonFactory.learningLesson(from: skill)
            apply(LearningProgress.fresh(for: lesson))
        }
    }

    private func navigate(to destination: LibraryRoute) {
        guard route != destination else { return }
        routeHistory.append(route)
        route = destination
    }
}
