import Foundation

/// Display-only resolution of shipped sample artwork. Never rewrites stored media or custom asset choices.
enum RuntimePhotos {
    private static let legacyNames: Set<String> = ["EchoHero", "EchoHome", "EchoReview", "EchoPrivacy", "EchoWoodwork"]

    static let captureCovers = [
        "FamilyPottery", "FamilyPaperCraft", "SkillBirdhouse", "FamilyRepair",
        "FamilyPiano", "FamilyFishing", "FamilyWatering", "FamilyBikeRepair"
    ]

    static func maker(_ asset: String, relation: String) -> String {
        guard legacyNames.contains(asset) else { return asset }
        switch relation.lowercased() {
        case "grandma": return "FamilySewing"
        case "grandpa": return "SkillWoodwork"
        case "dad": return "SkillBikeRepair"
        case "mom": return "SkillGardening"
        default: return "FamilyCooking"
        }
    }

    static func cover(_ asset: String, title: String) -> String {
        guard legacyNames.contains(asset) else { return asset }
        let title = title.lowercased()
        if title.contains("apple pie") { return "FamilyBaking" }
        if title.contains("wreath") { return "SkillWreath" }
        if title.contains("dumpling") { return "EchoHero" }
        if title.contains("paper") || title.contains("bookmark") { return "FamilyPaperCraft" }
        if title.contains("birdhouse") { return "SkillBirdhouse" }
        if title.contains("bike") || title.contains("bicycle") { return "SkillBikeRepair" }
        if title.contains("woodwork") { return "SkillWoodwork" }
        if title.contains("garden") { return "SkillGardening" }
        // Dumpling and pasta photographs are still awaited; other unknown choices stay unchanged.
        return asset
    }
}
