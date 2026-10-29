import SwiftUI

struct LibraryRootView: View {
    @StateObject private var coordinator: LibraryCoordinator
    @StateObject private var captureCoordinator: CaptureCoordinator
    @StateObject private var learnCoordinator: LearnCoordinator
    @StateObject private var familyProfileCoordinator: FamilyProfileCoordinator
    @State private var activeSection: AppSection
    private let publishedStore: UserDefaultsPublishedLessonStore

    init(repository: any SkillRepository, initialFamilyName: String? = nil, onResetApp: @escaping () -> Void = {}) {
        let arguments = ProcessInfo.processInfo.arguments
        let publishedStore = UserDefaultsPublishedLessonStore()
        self.publishedStore = publishedStore
        if arguments.contains("-resetPublishedLessons") {
            try? publishedStore.deleteAll()
        }
        let integratedRepository = IntegratedSkillRepository(
            base: repository,
            publishedDrafts: (try? publishedStore.load()) ?? []
        )
        let libraryCoordinator = LibraryCoordinator(repository: integratedRepository)
        let captureStore = UserDefaultsCaptureDraftStore()
        if arguments.contains("-resetCapture") {
            try? captureStore.delete()
        }
        let captureCoordinator = CaptureCoordinator(store: captureStore)
        let learnStore = UserDefaultsLearningProgressStore()
        if arguments.contains("-resetLearn") {
            try? learnStore.delete()
        }
        let learnCoordinator = LearnCoordinator(store: learnStore)
        let practiceArchive = UserDefaultsPracticeArchiveStore()
        let familyStore = UserDefaultsFamilyProfileStore()
        if arguments.contains("-resetFamilyProfile") {
            try? familyStore.delete()
        }
        let familyCoordinator = FamilyProfileCoordinator(
            store: familyStore,
            learningHistoryStore: learnStore,
            initialFamilyName: initialFamilyName,
            useExampleData: !repository.skills.isEmpty
        )
        familyCoordinator.exportDataProvider = { [weak familyCoordinator] includeMedia in
            try LocalExportBuilder().make(profile: familyCoordinator?.currentUser,
                                          familyName: familyCoordinator?.state.familyName ?? "My Family",
                                          settings: familyCoordinator?.state.settings ?? FamilySettings(),
                                          lessons: try publishedStore.load(), progress: try learnStore.loadAll(),
                                          practices: try practiceArchive.load(), includeMedia: includeMedia)
        }
        familyCoordinator.deletePracticesHandler = { [weak learnCoordinator] in
            let practices = try practiceArchive.load()
            for filename in Set(practices.compactMap { $0.practice.mediaFilename }) { try LocalMediaStore().delete(filename) }
            try practiceArchive.deleteAll()
            for var record in try learnStore.loadAll() { record.practice = .empty; try learnStore.save(record) }
            learnCoordinator?.clearPractice()
        }
        familyCoordinator.deleteLocalDataHandler = {
            try publishedStore.deleteAll()
            try captureStore.delete()
            try learnStore.delete()
            try practiceArchive.deleteAll()
            try familyStore.delete()
            try UserDefaultsMakerMemoryStore().save([:])
            try LocalMediaStore().deleteAll()
            onResetApp()
        }
        captureCoordinator.onPublished = { [weak libraryCoordinator, weak familyCoordinator, weak learnCoordinator] draft in
            try publishedStore.upsert(draft)
            libraryCoordinator?.upsertPublishedDraft(draft)
            familyCoordinator?.recordPublishedLesson(draft)
            familyCoordinator?.synchronizeLibrary(libraryCoordinator?.skills ?? [])
            learnCoordinator?.availableLessons.removeAll { $0.id == draft.id }
            learnCoordinator?.availableLessons.append(IntegratedLessonFactory.learningLesson(from: draft))
        }
        learnCoordinator.onProgressChanged = { [weak libraryCoordinator, weak familyCoordinator] progress in
            if progress.practice.submittedAt != nil {
                try? practiceArchive.upsert(lessonID: progress.lessonID,
                                           title: libraryCoordinator?.skill(withID: progress.lessonID)?.title ?? "Family lesson", practice: progress.practice)
            }
            libraryCoordinator?.apply(progress)
            familyCoordinator?.apply(progress, lessonTitle: libraryCoordinator?.skill(withID: progress.lessonID)?.title)
            familyCoordinator?.synchronizeLearningHistory((try? learnStore.loadAll()) ?? [])
        }
        familyCoordinator.onLearningHistoryDeleted = { [weak learnCoordinator, weak libraryCoordinator] in
            learnCoordinator?.clearLocalHistory()
            libraryCoordinator?.clearLearningProgress()
        }
        let savedProgress = (try? learnStore.loadAll()) ?? []
        let publishedDrafts = (try? publishedStore.load()) ?? []
        learnCoordinator.availableLessons = libraryCoordinator.skills.map { skill in
            if let draft = publishedDrafts.first(where: { $0.id == skill.id }) { return IntegratedLessonFactory.learningLesson(from: draft) }
            return IntegratedLessonFactory.learningLesson(from: skill)
        }
        familyCoordinator.synchronizeLibrary(libraryCoordinator.skills)
        for progress in savedProgress { libraryCoordinator.apply(progress) }
        familyCoordinator.synchronizeLearningHistory(savedProgress)
        if let latest = savedProgress.first,
           let skill = libraryCoordinator.skill(withID: latest.lessonID),
           !arguments.contains("-resetLearn") {
            let draft = ((try? publishedStore.load()) ?? []).first { $0.id == skill.id }
            let lesson = draft.map { IntegratedLessonFactory.learningLesson(from: $0) }
                ?? IntegratedLessonFactory.learningLesson(from: skill)
            learnCoordinator.load(lesson)
        }
        _coordinator = StateObject(wrappedValue: libraryCoordinator)
        _captureCoordinator = StateObject(wrappedValue: captureCoordinator)
        _learnCoordinator = StateObject(wrappedValue: learnCoordinator)
        if let routeIndex = arguments.firstIndex(of: "-familyRoute"), arguments.indices.contains(routeIndex + 1) {
            switch arguments[routeIndex + 1] {
            case "members": familyCoordinator.route = .members
            case "invite": familyCoordinator.route = .inviteMember
            case "permissions":
                if let member = familyCoordinator.state.members.first(where: { $0.name == "Rose Carter" }) { familyCoordinator.route = .memberPermissions(member.id) }
            case "activity": familyCoordinator.route = .familyActivity
            case "maker": familyCoordinator.route = .makerArchive
            case "profile": familyCoordinator.route = .profile
            case "settings": familyCoordinator.route = .settings
            case "storage": familyCoordinator.route = .storage
            case "notifications": familyCoordinator.route = .notifications
            case "privacy": familyCoordinator.route = .privacy
            case "data": familyCoordinator.route = .manageData
            case "deletion": familyCoordinator.route = .accountDeletion
            case "help": familyCoordinator.route = .help
            default: familyCoordinator.route = .familyOverview
            }
        }
        _familyProfileCoordinator = StateObject(wrappedValue: familyCoordinator)
        _activeSection = State(
            initialValue: arguments.contains("-openProfile") ? .profile
                : (arguments.contains("-openFamily") ? .family
                    : (arguments.contains("-openLearn") ? .learn
                        : (arguments.contains("-openCapture") ? .capture : .library)))
        )
    }

    var body: some View {
        ZStack {
            EchoTheme.ivory.ignoresSafeArea()
            currentScreen
        }
        .overlay(alignment: .top) {
            if !(activeSection == .capture && captureCoordinator.route == .recording) {
                GeometryReader { geometry in
                    EchoTheme.ivory
                        .frame(height: geometry.safeAreaInsets.top)
                        .offset(y: -geometry.safeAreaInsets.top)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if activeSection == .library
                || (activeSection == .capture && captureCoordinator.route == .entry)
                || (activeSection == .learn && learnCoordinator.isDashboardVisible)
                || (activeSection == .family && familyProfileCoordinator.route == .familyOverview)
                || (activeSection == .profile && familyProfileCoordinator.route == .profile) {
                LibraryTabBar(
                selected: activeSection,
                onLibrary: {
                    coordinator.goHome()
                    activeSection = .library
                },
                onCapture: { activeSection = .capture },
                onLearn: {
                    learnCoordinator.showDashboard()
                    activeSection = .learn
                },
                onFamily: {
                    familyProfileCoordinator.showFamily()
                    activeSection = .family
                },
                onProfile: openProfile
            )
            }
        }
        .alert(
            coordinator.unavailableFeature ?? "Coming later",
            isPresented: Binding(
                get: { coordinator.unavailableFeature != nil },
                set: { if !$0 { coordinator.unavailableFeature = nil } }
            )
        ) {
            Button("OK", role: .cancel) { coordinator.unavailableFeature = nil }
        } message: {
            Text("You can continue learning or choose another lesson action.")
        }
        .tint(EchoTheme.terracotta)
        .onChange(of: familyProfileCoordinator.handoff) { _, destination in
            guard let destination else { return }
            familyProfileCoordinator.handoff = nil
            switch destination {
            case .learningHistory:
                learnCoordinator.showHistory()
                activeSection = .learn
            case let .learn(id):
                if let skill = coordinator.skill(withID: id) { openLearning(skill) }
            case .library:
                coordinator.showAllSkills()
                activeSection = .library
            case .capture: activeSection = .capture
            case let .practice(id):
                if let skill = coordinator.skill(withID: id) {
                    learnCoordinator.load(learningLesson(for: skill))
                    if let archived = ((try? UserDefaultsPracticeArchiveStore().load()) ?? []).first(where: { $0.lessonID == id && $0.practice.isSharedWithFamily }) {
                        learnCoordinator.showArchivedPractice(archived.practice)
                        activeSection = .learn
                    } else { familyProfileCoordinator.notice = "This practice is no longer saved on this device." }
                }
            }
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        if activeSection == .capture {
            CaptureRootView(
                coordinator: captureCoordinator,
                onGoToLibrary: {
                    coordinator.goHome()
                    activeSection = .library
                },
                onViewLesson: {
                    coordinator.goHome()
                    coordinator.showSkill(captureCoordinator.draft.id)
                    activeSection = .library
                }
            )
        } else if activeSection == .learn {
            if coordinator.skills.isEmpty {
                EchoScreen {
                    Text("Your family classroom").font(EchoTheme.title(38))
                    Text("Publish your first lesson to begin learning.")
                    Button("Create a Lesson") { activeSection = .capture }.buttonStyle(EchoPrimaryButtonStyle())
                }
            } else { LearnRootView(coordinator: learnCoordinator) }
        } else if activeSection == .family || activeSection == .profile {
            FamilyRootView(coordinator: familyProfileCoordinator, onOpenProfile: openProfile)
        } else {
            switch coordinator.route {
            case .home:
                LibraryHomeView(coordinator: coordinator, profileCoordinator: familyProfileCoordinator,
                                onCapture: { activeSection = .capture }, onOpenProfile: openProfile)
            case .allSkills:
                AllSkillsView(coordinator: coordinator)
            case .search:
                LibrarySearchView(coordinator: coordinator)
            case let .skillDetail(id):
                if let skill = coordinator.skill(withID: id) {
                    SkillDetailView(
                        skill: skill,
                        coordinator: coordinator,
                        onContinueLearning: openLearning,
                        onAskQuestion: openQuestion,
                        onSelectStep: openStep
                    )
                } else {
                    LibraryMissingView(onBack: coordinator.goHome)
                }
            case let .makerProfile(id):
                if let maker = coordinator.maker(withID: id) {
                    MakerProfileView(maker: maker, coordinator: coordinator, onRecord: { selected in
                        captureCoordinator.preferredMaker = selected.name
                        captureCoordinator.returnToEntry()
                        activeSection = .capture
                    })
                } else {
                    LibraryMissingView(onBack: coordinator.goHome)
                }
            }
        }
    }

    private func openProfile() {
        familyProfileCoordinator.showProfile()
        activeSection = .profile
    }

    private func openLearning(_ skill: SkillLesson) {
        learnCoordinator.load(learningLesson(for: skill), startImmediately: true)
        activeSection = .learn
    }

    private func openQuestion(_ skill: SkillLesson) {
        learnCoordinator.load(learningLesson(for: skill))
        guard learnCoordinator.lesson.allowsQuestions != false else {
            coordinator.unavailableFeature = "The maker turned off questions for this lesson."
            return
        }
        learnCoordinator.askQuestion()
        activeSection = .learn
    }

    private func openStep(_ skill: SkillLesson, stepID: String) {
        openLearning(skill)
        if let index = learnCoordinator.lesson.steps.firstIndex(where: { $0.id == stepID }) {
            learnCoordinator.selectStep(index)
            learnCoordinator.beginSteps()
        }
    }

    private func learningLesson(for skill: SkillLesson) -> LearningLesson {
        if let draft = ((try? publishedStore.load()) ?? []).first(where: { $0.id == skill.id }) {
            return IntegratedLessonFactory.learningLesson(from: draft)
        }
        return IntegratedLessonFactory.learningLesson(from: skill)
    }
}

private enum AppSection: Equatable {
    case library
    case capture
    case learn
    case family
    case profile
}

private struct LibraryMissingView: View {
    let onBack: () -> Void

    var body: some View {
        EchoScreen {
            Spacer(minLength: 80)
            Text("This family item is no longer available.")
                .font(EchoTheme.title(34))
            Button("Back to Library", action: onBack)
                .buttonStyle(EchoPrimaryButtonStyle())
        }
    }
}

private struct LibraryTabBar: View {
    let selected: AppSection
    let onLibrary: () -> Void
    let onCapture: () -> Void
    let onLearn: () -> Void
    let onFamily: () -> Void
    let onProfile: () -> Void

    var body: some View {
        HStack {
            TabButton(title: "Library", icon: "house.fill", isSelected: selected == .library, action: onLibrary)
            TabButton(title: "Capture", icon: "camera", isSelected: selected == .capture, action: onCapture)
            TabButton(title: "Learn", icon: "play.rectangle", isSelected: selected == .learn, action: onLearn)
            TabButton(title: "Family", icon: "person.2", isSelected: selected == .family, action: onFamily)
            TabButton(title: "Profile", icon: "person", isSelected: selected == .profile, action: onProfile)
        }
        .padding(.horizontal, 8)
        .padding(.top, 9)
        .padding(.bottom, 4)
        .background(EchoTheme.paper)
        .overlay(alignment: .top) { Rectangle().fill(EchoTheme.line.opacity(0.7)).frame(height: 0.5) }
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 21, weight: .medium))
                Text(title).font(.caption2)
            }
            .foregroundStyle(isSelected ? EchoTheme.terracotta : EchoTheme.secondaryInk)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

struct LibraryBackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "chevron.left")
                .font(.headline)
                .frame(minHeight: 44)
        }
        .accessibilityLabel("Back to \(title)")
    }
}

struct MakerAvatar: View {
    let maker: FamilyMaker
    var size: CGFloat = 64

    var body: some View {
        Image(RuntimePhotos.maker(maker.imageName, relation: maker.relation))
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay { Circle().stroke(EchoTheme.paper, lineWidth: 2) }
            .accessibilityLabel("\(maker.relation), \(maker.name)")
    }
}
