import Testing
import UIKit
@testable import Craftkin

struct RuntimePhotoTests {
    @Test("Only known placeholder names are resolved; custom photo choices are preserved")
    func preservesPhotoChoices() {
        #expect(RuntimePhotos.maker("EchoReview", relation: "Dad") == "SkillBikeRepair")
        #expect(RuntimePhotos.maker("EchoHero", relation: "Grandma") == "FamilySewing")
        #expect(RuntimePhotos.maker("EchoWoodwork", relation: "Grandpa") == "SkillWoodwork")
        #expect(RuntimePhotos.maker("EchoHome", relation: "Mom") == "SkillGardening")
        #expect(RuntimePhotos.maker("MyPortrait", relation: "Dad") == "MyPortrait")
        #expect(RuntimePhotos.maker("EchoHero", relation: "You") == "FamilyCooking")
        #expect(RuntimePhotos.cover("EchoHero", title: "Fold a paper bookmark") == "FamilyPaperCraft")
        #expect(RuntimePhotos.cover("MyCover", title: "Fold a paper bookmark") == "MyCover")
        #expect(RuntimePhotos.cover("EchoHero", title: "Grandma’s Apple Pie") == "FamilyBaking")
        #expect(RuntimePhotos.cover("EchoHero", title: "Grandma's Dumplings") == "EchoHero")
        #expect(RuntimePhotos.cover("EchoPrivacy", title: "Holiday Wreath Making") == "SkillWreath")
        #expect(RuntimePhotos.cover("EchoWoodwork", title: "Build a Cedar Birdhouse") == "SkillBirdhouse")
        #expect(RuntimePhotos.cover("EchoReview", title: "Bicycle repair") == "SkillBikeRepair")
        #expect(RuntimePhotos.cover("EchoReview", title: "Dad’s Bike Repair") == "SkillBikeRepair")
        #expect(RuntimePhotos.cover("EchoWoodwork", title: "Woodwork") == "SkillWoodwork")
        #expect(RuntimePhotos.cover("EchoHome", title: "Garden cuttings") == "SkillGardening")
    }

    @Test("Every additional illustrative photograph is in the app bundle", arguments: [
        "SkillBirdhouse", "FamilyPaperCraft", "FamilyPottery", "FamilyRepair",
        "FamilyPiano", "FamilyFishing", "FamilyWatering", "FamilyBikeRepair", "SkillPasta"
    ])
    @MainActor func additionalPhotosLoad(name: String) {
        #expect(UIImage(named: name) != nil)
    }

    @Test("Cover suggestions are distinct photographs, not claimed video frames")
    func coverSuggestions() {
        #expect(Set(RuntimePhotos.captureCovers).count == RuntimePhotos.captureCovers.count)
        #expect(RuntimePhotos.captureCovers.count == 8)
        #expect(RuntimePhotos.captureCovers.allSatisfy { !$0.hasPrefix("Echo") })
    }

    @Test("Display resolution keeps an old published draft intact and updates both Library and Learn")
    func savedDraftDisplayResolution() throws {
        var draft = CaptureDraft.sample
        draft.title = "Fold a paper bookmark"
        draft.lifecycle = .published
        let original = draft
        #expect(try #require(IntegratedLessonFactory.librarySkill(from: draft)).coverImageName == "FamilyPaperCraft")
        #expect(IntegratedLessonFactory.learningLesson(from: draft).imageName == "FamilyPaperCraft")
        #expect(draft == original)
        #expect(CaptureDraft.fresh().selectedCover == "FamilyPottery")
        #expect(CaptureDraft.sample.selectedCover == "EchoHero")
    }
}
