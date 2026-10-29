import Foundation

protocol PublishedLessonStoring {
    func load() throws -> [CaptureDraft]
    func upsert(_ draft: CaptureDraft) throws
    func deleteAll() throws
}

final class UserDefaultsPublishedLessonStore: PublishedLessonStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "echoskill.library.publishedLessons.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> [CaptureDraft] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([CaptureDraft].self, from: data)
    }

    func upsert(_ draft: CaptureDraft) throws {
        var drafts = try load()
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = draft
        } else {
            drafts.append(draft)
        }
        defaults.set(try JSONEncoder().encode(drafts), forKey: key)
    }

    func deleteAll() throws {
        defaults.removeObject(forKey: key)
    }
}

final class InMemoryPublishedLessonStore: PublishedLessonStoring {
    private var drafts: [CaptureDraft]
    init(drafts: [CaptureDraft] = []) { self.drafts = drafts }
    func load() throws -> [CaptureDraft] { drafts }
    func upsert(_ draft: CaptureDraft) throws {
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = draft
        } else {
            drafts.append(draft)
        }
    }
    func deleteAll() throws { drafts = [] }
}

struct IntegratedSkillRepository: SkillRepository {
    let skills: [SkillLesson]
    let makers: [FamilyMaker]

    init(base: any SkillRepository, publishedDrafts: [CaptureDraft]) {
        let publishedSkills = publishedDrafts.compactMap { IntegratedLessonFactory.librarySkill(from: $0) }
        var mergedSkills = base.skills
        for skill in publishedSkills {
            if let index = mergedSkills.firstIndex(where: { $0.id == skill.id }) {
                mergedSkills[index] = skill
            } else {
                mergedSkills.append(skill)
            }
        }
        skills = mergedSkills

        var mergedMakers = base.makers
        for maker in publishedSkills.map(\.maker) where !mergedMakers.contains(where: { $0.id == maker.id }) {
            mergedMakers.append(maker)
        }
        makers = mergedMakers
    }
}

enum IntegratedLessonFactory {
    static func librarySkill(from draft: CaptureDraft) -> SkillLesson? {
        guard draft.lifecycle == .published,
              draft.metadataErrors.isEmpty,
              draft.hasValidStepRanges else { return nil }

        let normalizedMaker = draft.maker.trimmingCharacters(in: .whitespacesAndNewlines)
        let relation = inferredRelation(from: normalizedMaker)
        let maker = FamilyMaker(
            id: slug(normalizedMaker),
            name: normalizedMaker,
            relation: relation,
            imageName: RuntimePhotos.cover(draft.selectedCover, title: draft.title),
            roles: "Family teacher · Story keeper",
            quote: draft.familyStory.isEmpty ? "Learn it together, then pass it on." : draft.familyStory,
            story: draft.familyStory.isEmpty ? "This lesson was recorded and reviewed by the family." : draft.familyStory
        )
        let transcript = draft.transcript.map(\.text).joined(separator: " ")
        return SkillLesson(
            id: draft.id,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: draft.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Family Skills" : draft.category,
            maker: maker,
            coverImageName: RuntimePhotos.cover(draft.selectedCover, title: draft.title),
            stepCount: draft.steps.count,
            durationMinutes: max(1, Int(ceil(draft.sourceDuration / 60))),
            completedSteps: 0,
            progress: .new,
            materials: draft.ingredients.map { item in
                [item.quantity, item.name].filter { !$0.isEmpty }.joined(separator: " ")
            },
            tools: draft.tools.map(\.name),
            transcript: transcript.isEmpty ? "Original family guidance preserved with this lesson." : transcript,
            steps: draft.steps.map { step in
                LessonStep(
                    id: step.id,
                    title: step.title,
                    minutes: max(1, Int(ceil((step.end - step.start) / 60))),
                    isComplete: false
                )
            },
            addedOrder: Int(Date().timeIntervalSince1970),
            learnedOrder: 0
        )
    }

    static func learningLesson(from skill: SkillLesson) -> LearningLesson {
        if skill.id == LearningLesson.sample.id { return .sample }

        var cursor: TimeInterval = 0
        let learningSteps = skill.steps.map { step -> LearningStep in
            let start = cursor
            let end = start + TimeInterval(max(step.minutes, 1) * 60)
            cursor = end
            return LearningStep(
                id: step.id,
                title: step.title,
                instruction: "Follow the recorded family guidance for this step.",
                familyTip: skill.transcript,
                sourceLabel: "\(skill.maker.relation)’s lesson · \(step.title)",
                start: start,
                end: end
            )
        }
        let materials = (skill.materials + skill.tools).enumerated().map { index, item in
            LearningMaterial(id: "\(skill.id)-material-\(index)", name: item, detail: index < skill.materials.count ? "Material" : "Tool")
        }
        return LearningLesson(
            id: skill.id,
            revisionID: "\(skill.id)-local-v1",
            title: skill.title,
            makerName: skill.maker.name,
            makerRelation: skill.maker.relation,
            imageName: skill.coverImageName,
            durationMinutes: skill.durationMinutes,
            materials: materials,
            steps: learningSteps,
            knowledge: [
                LessonKnowledge(
                    id: "\(skill.id)-original-guidance",
                    keywords: skill.transcript.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 },
                    answer: skill.transcript,
                    source: "Original family guidance"
                )
            ]
        )
    }

    static func learningLesson(from draft: CaptureDraft) -> LearningLesson {
        LearningLesson(
            id: draft.id,
            revisionID: "\(draft.id)-local-v1",
            title: draft.title,
            makerName: draft.maker,
            makerRelation: inferredRelation(from: draft.maker),
            imageName: RuntimePhotos.cover(draft.selectedCover, title: draft.title),
            durationMinutes: max(1, Int(ceil(draft.sourceDuration / 60))),
            materials: (draft.ingredients + draft.tools).map {
                LearningMaterial(id: $0.id, name: $0.name, detail: $0.quantity)
            },
            steps: draft.steps.map { step in
                LearningStep(id: step.id, title: step.title, instruction: step.instruction,
                             familyTip: step.caution, sourceLabel: "Reviewed lesson · \(step.title)",
                             start: step.start, end: step.end)
            },
            knowledge: draft.transcript.map { segment in
                LessonKnowledge(id: segment.id,
                                keywords: segment.text.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 },
                                answer: segment.text, source: "Original transcript · \(sourceTimestamp(segment.start))")
            },
            sourceMediaFilename: draft.sourceMediaFilename,
            allowsQuestions: draft.allowsQuestions
        )
    }

    private static func sourceTimestamp(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func inferredRelation(from maker: String) -> String {
        let known = ["Grandma", "Grandpa", "Mom", "Dad", "Aunt", "Uncle"]
        return known.first(where: { maker.localizedCaseInsensitiveContains($0) }) ?? "Family"
    }

    private static func slug(_ text: String) -> String {
        let allowed = text.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "-" }
        return String(allowed).split(separator: "-").joined(separator: "-")
    }
}
