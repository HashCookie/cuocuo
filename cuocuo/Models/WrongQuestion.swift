import Foundation
import SwiftData

@Model
final class WrongQuestion {
    @Attribute(.unique) var id: UUID
    var moduleRaw: String
    var subtype: String?
    var questionText: String
    var analysisText: String
    var causeTags: [String]
    var masteryRaw: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ScanPage.question)
    var pages: [ScanPage]

    init(
        id: UUID,
        module: ExamModule,
        subtype: String?,
        questionText: String,
        analysisText: String,
        causeTags: [String],
        mastery: Mastery,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.moduleRaw = module.rawValue
        self.subtype = subtype
        self.questionText = questionText
        self.analysisText = analysisText
        self.causeTags = causeTags
        self.masteryRaw = mastery.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pages = []
    }

    var module: ExamModule {
        get { ExamModule(rawValue: moduleRaw) ?? .verbal }
        set { moduleRaw = newValue.rawValue }
    }

    var mastery: Mastery {
        get { Mastery(rawValue: masteryRaw) ?? .unmastered }
        set { masteryRaw = newValue.rawValue }
    }

    var questionPages: [ScanPage] {
        pages.filter { $0.kind == .question }.sorted { $0.order < $1.order }
    }

    var analysisPages: [ScanPage] {
        pages.filter { $0.kind == .analysis }.sorted { $0.order < $1.order }
    }

    var summaryLine: String {
        let first = questionText
            .split(whereSeparator: \.isNewline)
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        return first.isEmpty ? "未识别出文字" : first
    }

    func matches(query: String) -> Bool {
        if query.isEmpty { return true }
        let fields = [questionText, analysisText, subtype ?? ""] + causeTags
        return fields.contains { $0.localizedStandardContains(query) }
    }
}

@Model
final class ScanPage {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var order: Int
    var relativePath: String
    var recognizedText: String
    var question: WrongQuestion?

    init(
        id: UUID,
        kind: PageKind,
        order: Int,
        relativePath: String,
        recognizedText: String
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.order = order
        self.relativePath = relativePath
        self.recognizedText = recognizedText
        self.question = nil
    }

    var kind: PageKind {
        get { PageKind(rawValue: kindRaw) ?? .question }
        set { kindRaw = newValue.rawValue }
    }
}
