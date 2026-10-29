import Foundation

protocol SkillRepository {
    var skills: [SkillLesson] { get }
    var makers: [FamilyMaker] { get }
}

struct LocalSampleSkillRepository: SkillRepository {
    let skills: [SkillLesson]
    let makers: [FamilyMaker]

    init(state: LibraryFixtureState) {
        guard state == .populated else {
            skills = []
            makers = []
            return
        }

        let grandma = FamilyMaker(
            id: "grandma",
            name: "Margaret Carter",
            relation: "Grandma",
            imageName: "FamilySewing",
            roles: "Family baker · Gardener · Story keeper",
            quote: "The little details are what make it yours.",
            story: "Margaret learned to bake beside her mother and has shared Sunday pies with the family for more than forty years."
        )
        let dad = FamilyMaker(
            id: "dad",
            name: "Daniel Carter",
            relation: "Dad",
            imageName: "SkillBikeRepair",
            roles: "Repairer · Patient teacher",
            quote: "Start slowly and listen to what the machine tells you.",
            story: "Daniel has kept the family bicycles and furniture in working order for decades."
        )
        let grandpa = FamilyMaker(
            id: "grandpa",
            name: "Robert Carter",
            relation: "Grandpa",
            imageName: "SkillWoodwork",
            roles: "Woodworker · Builder · Grandfather",
            quote: "Measure carefully, then let the grain guide you.",
            story: "Robert learned woodworking from his uncle and still makes a small gift for every new family member."
        )
        let mom = FamilyMaker(
            id: "mom",
            name: "Emma Carter",
            relation: "Mom",
            imageName: "SkillGardening",
            roles: "Gardener · Family organizer",
            quote: "A cutting is a promise that the garden continues.",
            story: "Emma keeps plants from every home the family has shared."
        )
        makers = [grandma, dad, grandpa, mom]

        skills = [
            SkillLesson(
                id: "apple-pie", title: "Grandma’s Apple Pie", category: "Recipes", maker: grandma,
                coverImageName: "FamilyBaking", stepCount: 8, durationMinutes: 18, completedSteps: 4,
                progress: .inProgress,
                materials: ["6 apples", "Pie dough", "Cinnamon"], tools: ["Rolling pin", "Pie dish"],
                transcript: "Leave small gaps so the steam can escape from the lattice.",
                steps: [
                    LessonStep(id: "pie-1", title: "Prepare the dough", minutes: 3, isComplete: true),
                    LessonStep(id: "pie-2", title: "Slice and season the apples", minutes: 4, isComplete: true),
                    LessonStep(id: "pie-3", title: "Build the lattice top", minutes: 5, isComplete: false)
                ], addedOrder: 6, learnedOrder: 9
            ),
            SkillLesson(
                id: "bike-repair", title: "Dad’s Bike Repair", category: "Repairs", maker: dad,
                coverImageName: "SkillBikeRepair", stepCount: 6, durationMinutes: 14, completedSteps: 0,
                progress: .new,
                materials: ["Chain oil", "Clean cloth"], tools: ["Allen key", "Wrench"],
                transcript: "Check the brakes before adjusting the chain tension.",
                steps: [LessonStep(id: "bike-1", title: "Inspect the bicycle", minutes: 3, isComplete: false)],
                addedOrder: 5, learnedOrder: 1
            ),
            SkillLesson(
                id: "woodwork", title: "Grandpa’s Woodwork", category: "Crafts", maker: grandpa,
                coverImageName: "SkillWoodwork", stepCount: 8, durationMinutes: 22, completedSteps: 8,
                progress: .completed,
                materials: ["Oak board", "Finishing oil"], tools: ["Hand plane", "Clamps"],
                transcript: "Plane and finish the wood grain in long even passes.",
                steps: [LessonStep(id: "wood-1", title: "Read the wood grain", minutes: 4, isComplete: true)],
                addedOrder: 4, learnedOrder: 7
            ),
            SkillLesson(
                id: "birdhouse", title: "Build a Cedar Birdhouse", category: "Crafts", maker: grandpa,
                coverImageName: "SkillBirdhouse", stepCount: 6, durationMinutes: 20, completedSteps: 0,
                progress: .new,
                materials: ["Cedar wood", "Outdoor screws"], tools: ["Hand saw", "Wood glue"],
                transcript: "Choose dry cedar wood and leave a drainage gap.",
                steps: [LessonStep(id: "bird-1", title: "Mark the cedar wood", minutes: 3, isComplete: false)],
                addedOrder: 3, learnedOrder: 2
            ),
            SkillLesson(
                id: "garden", title: "Grandpa’s Garden Cuttings", category: "Gardening", maker: grandpa,
                coverImageName: "SkillGardening", stepCount: 5, durationMinutes: 12, completedSteps: 5,
                progress: .completed,
                materials: ["Healthy stems", "Potting mix"], tools: ["Garden snips"],
                transcript: "Take a clean cutting just below a leaf node.",
                steps: [LessonStep(id: "garden-1", title: "Choose a healthy stem", minutes: 2, isComplete: true)],
                addedOrder: 2, learnedOrder: 6
            ),
            SkillLesson(
                id: "wreath", title: "Holiday Wreath Making", category: "Traditions", maker: grandma,
                coverImageName: "SkillWreath", stepCount: 6, durationMinutes: 16, completedSteps: 0,
                progress: .saved,
                materials: ["Evergreen branches", "Ribbon"], tools: ["Floral wire", "Snips"],
                transcript: "Layer each evergreen branch in the same direction.",
                steps: [LessonStep(id: "wreath-1", title: "Shape the evergreen base", minutes: 4, isComplete: false)],
                addedOrder: 1, learnedOrder: 3
            )
        ]
    }
}
