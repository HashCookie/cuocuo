import Foundation
import SwiftData

@MainActor
enum QuestionStore {
    static func save(draft: QuestionDraft, existing: WrongQuestion?, in context: ModelContext) throws {
        let question = try upsert(draft: draft, existing: existing, in: context)
        try syncPages(draft: draft, question: question, in: context)
        try context.save()
        ImageStore.cleanup(questionID: question.id, keep: Set(draft.pages.map(\.relativePath)))
    }

    static func delete(_ question: WrongQuestion, in context: ModelContext) throws {
        let id = question.id
        context.delete(question)
        try context.save()
        ImageStore.deleteFolder(questionID: id)
    }

    static func setMastered(_ isMastered: Bool, question: WrongQuestion, in context: ModelContext) throws {
        question.mastery = isMastered ? .mastered : .unmastered
        question.updatedAt = .now
        try context.save()
    }

    private static func upsert(
        draft: QuestionDraft,
        existing: WrongQuestion?,
        in context: ModelContext
    ) throws -> WrongQuestion {
        let now = Date()
        if let existing {
            existing.module = draft.module
            existing.subtype = cleanedSubtype(draft.subtype)
            existing.questionText = cleaned(draft.questionText)
            existing.analysisText = cleaned(draft.analysisText)
            existing.causeTags = cleanedTags(draft.causeTags)
            existing.mastery = draft.mastery
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
            mastery: draft.mastery,
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
