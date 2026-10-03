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
    var choiceLetters: [String] = ["A", "B", "C", "D"]
    var correctChoice: String?
    var choiceClipLetters: [String] = []
    var choiceClipPaths: [String] = []
    var masteryRaw: String
    var nextReviewAt: Date?
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
        choiceLetters: [String] = ChoiceOptions.standard,
        correctChoice: String? = nil,
        mastery: Mastery,
        nextReviewAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.moduleRaw = module.rawValue
        self.subtype = subtype
        self.questionText = questionText
        self.analysisText = analysisText
        self.causeTags = causeTags
        self.choiceLetters = ChoiceOptions.normalized(choiceLetters)
        self.correctChoice = correctChoice
        self.choiceClipLetters = []
        self.choiceClipPaths = []
        self.masteryRaw = mastery.rawValue
        self.nextReviewAt = nextReviewAt
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

    var answerChoices: [String] {
        ChoiceOptions.normalized(choiceLetters)
    }

    func choiceClipPath(for letter: String) -> String? {
        guard let index = choiceClipLetters.firstIndex(of: letter) else { return nil }
        guard choiceClipPaths.indices.contains(index) else { return nil }
        let path = choiceClipPaths[index]
        return path.isEmpty ? nil : path
    }

    var summaryLine: String {
        let first = questionText
            .split(whereSeparator: \.isNewline)
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        if !first.isEmpty { return first }
        if let subtype, !subtype.isEmpty { return subtype }
        return "图片题"
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
