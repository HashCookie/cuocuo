import Foundation
import SwiftData

@MainActor
enum QuestionStore {
    static func save(draft: QuestionDraft, existing: WrongQuestion?, in context: ModelContext) throws {
        let question = try upsert(draft: draft, existing: existing, in: context)
        try syncPages(draft: draft, question: question, in: context)
        if draft.choiceClipsEdited {
            let letters = draft.choiceClips.keys.sorted()
            var paths: [String] = []
            for letter in letters {
                guard let jpeg = draft.choiceClips[letter] else { continue }
                let path = try ImageStore.writeNamed(jpeg, questionID: question.id, name: "choice-\(letter).jpg")
                paths.append(path)
            }
            question.choiceClipLetters = letters
            question.choiceClipPaths = paths
        }
        try context.save()
        var keep = Set(draft.pages.map(\.relativePath))
        keep.formUnion(question.choiceClipPaths)
        ImageStore.cleanup(questionID: question.id, keep: keep)
        ReviewReminder.refresh(in: context)
    }

    static func delete(_ question: WrongQuestion, in context: ModelContext) throws {
        let id = question.id
        context.delete(question)
        try context.save()
        ImageStore.deleteFolder(questionID: id)
        ReviewReminder.refresh(in: context)
    }

    static func setMastered(_ isMastered: Bool, question: WrongQuestion, in context: ModelContext) throws {
        question.mastery = isMastered ? .mastered : .unmastered
        question.nextReviewAt = isMastered ? nil : .now
        question.updatedAt = .now
        try context.save()
        ReviewReminder.refresh(in: context)
    }

    static func setCorrectChoice(_ letter: String, question: WrongQuestion, in context: ModelContext) throws {
        guard question.answerChoices.contains(letter) else { return }
        question.correctChoice = letter
        question.updatedAt = .now
        try context.save()
    }

    static func scheduleAgain(_ question: WrongQuestion, in context: ModelContext) throws {
        question.mastery = .unmastered
        question.nextReviewAt = ReviewSchedule.nextDate()
        question.updatedAt = .now
        try context.save()
        ReviewReminder.refresh(in: context)
    }

    private static func upsert(
        draft: QuestionDraft,
        existing: WrongQuestion?,
        in context: ModelContext
    ) throws -> WrongQuestion {
        let now = Date()
        if let existing {
            let wasMastered = existing.mastery == .mastered
            existing.module = draft.module
            existing.subtype = cleanedSubtype(draft.subtype)
            existing.questionText = cleaned(draft.questionText)
            existing.analysisText = cleaned(draft.analysisText)
            existing.causeTags = cleanedTags(draft.causeTags)
            existing.choiceLetters = draft.answerChoices
            existing.correctChoice = cleanedChoice(draft.correctChoice, allowed: draft.answerChoices)
            existing.mastery = draft.mastery
            if draft.mastery == .mastered {
                existing.nextReviewAt = nil
            } else if wasMastered || existing.nextReviewAt == nil {
                existing.nextReviewAt = now
            }
            existing.updatedAt = now
            return existing
        }
        let question = WrongQuestion(
            id: draft.id,
            module: draft.module,
            subtype: cleanedSubtype(draft.subtype),
            questionText: cleaned(draft.questionText),
            analysisText: cleaned(draft.analysisText),
            causeTags: cleanedTags(draft.causeTags),
            choiceLetters: draft.answerChoices,
            correctChoice: cleanedChoice(draft.correctChoice, allowed: draft.answerChoices),
            mastery: draft.mastery,
            nextReviewAt: draft.mastery == .unmastered ? now : nil,
            createdAt: now,
            updatedAt: now
        )
        context.insert(question)
        return question
    }

    private static func syncPages(draft: QuestionDraft, question: WrongQuestion, in context: ModelContext) throws {
        let kept = Set(draft.pages.map(\.id))
        let existingByID = Dictionary(uniqueKeysWithValues: question.pages.map { ($0.id, $0) })
        for page in existingByID.values where !kept.contains(page.id) {
            context.delete(page)
        }
        for draftPage in draft.pages {
            if let page = existingByID[draftPage.id] {
                page.kind = draftPage.kind
                page.order = draftPage.order
                page.relativePath = draftPage.relativePath
                page.recognizedText = draftPage.recognizedText
            } else {
                let page = ScanPage(
                    id: draftPage.id,
                    kind: draftPage.kind,
                    order: draftPage.order,
                    relativePath: draftPage.relativePath,
                    recognizedText: draftPage.recognizedText
                )
                page.question = question
                context.insert(page)
            }
        }
    }

    private static func cleanedChoice(_ choice: String?, allowed: [String]) -> String? {
        guard let choice, allowed.contains(choice) else { return nil }
        return choice
    }

    private static func cleaned(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanedSubtype(_ subtype: String?) -> String? {
        let trimmed = subtype?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func cleanedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in tags {
            let trimmed = String(tag.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12))
            if trimmed.isEmpty || seen.contains(trimmed) { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }
}
