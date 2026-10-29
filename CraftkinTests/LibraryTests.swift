import Foundation
import Testing
import UIKit
@testable import Craftkin

@MainActor
struct LocalSkillRepositoryTests {
    @Test("Normal launch includes all bundled lessons while explicit empty fixtures remain testable")
    func defaultLibraryIncludesSamples() {
        #expect(LibraryFixtureState.launchState(arguments: []) == .populated)
        #expect(LibraryFixtureState.launchState(arguments: ["-openLibrary"]) == .populated)
        #expect(LibraryFixtureState.launchState(arguments: ["-libraryFixture", "empty"]) == .empty)
        #expect(LibraryFixtureState.launchState(arguments: ["-libraryFixture", "populated"]) == .populated)
        #expect(LibraryFixtureState.launchState(arguments: ["-libraryFixture", "unknown"]) == .populated)
        #expect(LibraryFixtureState.launchState(arguments: ["-libraryFixture"]) == .populated)
        #expect(CaptureDraft.sample.language == "English")
    }

    @Test("Supplied skill photographs replace only matching lesson covers")
    func suppliedPhotoMappings() throws {
        let skills = LocalSampleSkillRepository(state: .populated).skills
        #expect(try #require(skills.first { $0.id == "bike-repair" }).coverImageName == "SkillBikeRepair")
        #expect(try #require(skills.first { $0.id == "woodwork" }).coverImageName == "SkillWoodwork")
        #expect(try #require(skills.first { $0.id == "garden" }).coverImageName == "SkillGardening")
        #expect(try #require(skills.first { $0.id == "apple-pie" }).coverImageName == "FamilyBaking")
        #expect(try #require(skills.first { $0.id == "birdhouse" }).coverImageName == "SkillBirdhouse")
        #expect(try #require(skills.first { $0.id == "wreath" }).coverImageName == "SkillWreath")
        let garden = try #require(skills.first { $0.id == "garden" })
        #expect(garden.title == "Grandpa’s Garden Cuttings")
        #expect(garden.maker.id == "grandpa")
        #expect(LearningLesson.sample.imageName == "FamilyBaking")
        #expect(UIImage(named: "SkillWreath") != nil)
    }

    @Test("Every supplied runtime photo loads from the app asset catalog", arguments: [
        "FamilyCooking", "FamilyBaking", "FamilySewing", "SkillBikeRepair", "SkillWoodwork", "SkillGardening"
    ])
    func suppliedPhotosAreBundled(name: String) {
        #expect(UIImage(named: name) != nil)
    }

    @Test("The populated fixture provides a credible private family library")
    func populatedFixture() {
        let repository = LocalSampleSkillRepository(state: .populated)

        #expect(repository.skills.count >= 6)
        #expect(repository.makers.count >= 3)
        #expect(repository.skills.allSatisfy { !$0.title.isEmpty && $0.stepCount > 0 })
    }

    @Test("An explicitly empty fixture still provides the empty-state test scenario")
    func emptyFixture() {
        let repository = LocalSampleSkillRepository(state: .empty)

        #expect(repository.skills.isEmpty)
        #expect(repository.makers.isEmpty)
    }
}

@MainActor
struct LibraryQueryTests {
    private let skills = LocalSampleSkillRepository(state: .populated).skills

    @Test("Search covers titles, makers, materials, tools, transcripts and steps")
    func searchesPrivateMetadata() {
        #expect(LibraryQueryEngine.search(skills, for: "apple").contains { $0.title == "Grandma’s Apple Pie" })
        #expect(LibraryQueryEngine.search(skills, for: "Grandpa").allSatisfy { $0.maker.relation == "Grandpa" })
        #expect(LibraryQueryEngine.search(skills, for: "plane").contains { $0.title == "Grandpa’s Woodwork" })
        #expect(LibraryQueryEngine.search(skills, for: "steam").contains { $0.title == "Grandma’s Apple Pie" })
        #expect(LibraryQueryEngine.search(skills, for: "VIOLIN").isEmpty)
    }

    @Test("Filters combine maker, category and progress")
    func combinesFilters() {
        let filter = LibraryFilter(
            makerIDs: ["grandma"],
            categories: ["Recipes"],
            progress: .inProgress,
            sort: .recentlyAdded
        )

        let result = LibraryQueryEngine.apply(filter, to: skills)

        #expect(result.map(\.title) == ["Grandma’s Apple Pie"])
    }

    @Test("Sorting supports alphabetical and recently learned order")
    func sortsResults() throws {
        let alphabetical = LibraryQueryEngine.apply(
            LibraryFilter(sort: .alphabetical),
            to: skills
        )
        let recentlyLearned = LibraryQueryEngine.apply(
            LibraryFilter(sort: .recentlyLearned),
            to: skills
        )

        #expect(alphabetical.map(\.title) == alphabetical.map(\.title).sorted())
        #expect(try #require(recentlyLearned.first).title == "Grandma’s Apple Pie")
    }
}

@MainActor
struct LibraryCoordinatorTests {
    @Test("Library navigation reaches all skills, details and maker profiles")
    func navigatesLibrary() throws {
        let repository = LocalSampleSkillRepository(state: .populated)
        let coordinator = LibraryCoordinator(repository: repository)
        let skill = try #require(repository.skills.first)

        coordinator.showAllSkills()
        #expect(coordinator.route == .allSkills)
        coordinator.showSkill(skill.id)
        #expect(coordinator.route == .skillDetail(skill.id))
        coordinator.showMaker(skill.maker.id)
        #expect(coordinator.route == .makerProfile(skill.maker.id))
        coordinator.goHome()
        #expect(coordinator.route == .home)
    }

    @Test("Back returns to the actual screen that opened a lesson")
    func restoresLessonOrigin() throws {
        let repository = LocalSampleSkillRepository(state: .populated)
        let skill = try #require(repository.skills.first)

        let homeCoordinator = LibraryCoordinator(repository: repository)
        homeCoordinator.showSkill(skill.id)
        homeCoordinator.goBack()
        #expect(homeCoordinator.route == .home)

        let allSkillsCoordinator = LibraryCoordinator(repository: repository)
        allSkillsCoordinator.showAllSkills()
        allSkillsCoordinator.showSkill(skill.id)
        allSkillsCoordinator.goBack()
        #expect(allSkillsCoordinator.route == .allSkills)

        let searchCoordinator = LibraryCoordinator(repository: repository)
        searchCoordinator.beginSearch()
        searchCoordinator.searchText = "apple"
        searchCoordinator.showSkill(skill.id)
        searchCoordinator.goBack()
        #expect(searchCoordinator.route == .search)
        #expect(searchCoordinator.searchText == "apple")
    }

    @Test("Back from a maker returns to the lesson that opened the profile")
    func restoresLessonFromMaker() throws {
        let repository = LocalSampleSkillRepository(state: .populated)
        let coordinator = LibraryCoordinator(repository: repository)
        let skill = try #require(repository.skills.first)

        coordinator.showSkill(skill.id)
        coordinator.showMaker(skill.maker.id)
        coordinator.goBack()

        #expect(coordinator.route == .skillDetail(skill.id))
    }

    @Test("Search reports matching and no-result states and can be cleared")
    func managesSearch() {
        let coordinator = LibraryCoordinator(
            repository: LocalSampleSkillRepository(state: .populated)
        )

        coordinator.beginSearch()
        coordinator.searchText = "wood"
        #expect(coordinator.searchResults.count == 2)
        coordinator.searchText = "violin"
        #expect(coordinator.searchResults.isEmpty)
        coordinator.clearSearch()
        #expect(coordinator.searchText.isEmpty)
        #expect(coordinator.route == .allSkills)
    }

    @Test("Applying and clearing filters updates visible skills")
    func managesFilters() {
        let coordinator = LibraryCoordinator(
            repository: LocalSampleSkillRepository(state: .populated)
        )

        coordinator.apply(
            LibraryFilter(
                makerIDs: ["grandpa"],
                categories: ["Crafts"],
                progress: nil,
                sort: .recentlyAdded
            )
        )
        #expect(coordinator.visibleSkills.count == 2)
        coordinator.clearFilters()
        #expect(coordinator.visibleSkills.count == coordinator.skills.count)
    }
}
