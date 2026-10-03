import Foundation

struct DraftPage: Identifiable, Equatable {
    var id: UUID
    var kind: PageKind
    var order: Int
    var relativePath: String
    var recognizedText: String
    var isRecognizing: Bool
    var recognitionFailed: Bool
}

struct DraftFingerprint: Equatable {
    var module: ExamModule
    var subtype: String?
    var questionText: String
    var analysisText: String
    var causeTags: [String]
    var includesFifthChoice: Bool
    var correctChoice: String?
    var choiceClipLetters: [String]
    var mastery: Mastery
    var pages: [PageFingerprint]
}

struct PageFingerprint: Equatable {
    var id: UUID
    var kind: PageKind
    var order: Int
    var relativePath: String
    var recognizedText: String
}

struct QuestionDraft {
    var id: UUID
    var module: ExamModule
    var subtype: String?
    var questionText: String
    var analysisText: String
    var questionTextEdited: Bool
    var analysisTextEdited: Bool
    var causeTags: [String]
    var includesFifthChoice: Bool
    var correctChoice: String?
    var savedClipLetters: [String]
    var choiceClips: [String: Data]
    var choiceClipsEdited: Bool
    var mastery: Mastery
    var pages: [DraftPage]
    var isNew: Bool
    var originalPaths: Set<String>
    private(set) var baseline: DraftFingerprint

    var hasQuestionPage: Bool {
        pages.contains { $0.kind == .question }
    }

    var hasAnalysisMaterial: Bool {
        if pages.contains(where: { $0.kind == .analysis }) { return true }
        return !analysisText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isRecognizing: Bool {
        pages.contains(where: \.isRecognizing)
    }

    var canSave: Bool {
        hasQuestionPage && !isRecognizing
    }

    var isDirty: Bool {
        fingerprint() != baseline
    }

    init(module: ExamModule) {
        id = UUID()
        self.module = module
        subtype = nil
        questionText = ""
        analysisText = ""
        questionTextEdited = false
        analysisTextEdited = false
        causeTags = []
        includesFifthChoice = false
        correctChoice = nil
        savedClipLetters = []
        choiceClips = [:]
        choiceClipsEdited = false
        mastery = .unmastered
        pages = []
        isNew = true
        originalPaths = []
        baseline = DraftFingerprint(
            module: module,
            subtype: nil,
            questionText: "",
            analysisText: "",
            causeTags: [],
            includesFifthChoice: false,
            correctChoice: nil,
            choiceClipLetters: [],
            mastery: .unmastered,
            pages: []
        )
    }

    var answerChoices: [String] {
        includesFifthChoice ? ChoiceOptions.all : ChoiceOptions.standard
    }

    init(question: WrongQuestion) {
        let loaded = question.pages.map { page in
            DraftPage(
                id: page.id,
                kind: page.kind,
                order: page.order,
                relativePath: page.relativePath,
                recognizedText: page.recognizedText,
                isRecognizing: false,
                recognitionFailed: page.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        id = question.id
        module = question.module
        subtype = question.subtype
        questionText = question.questionText
        analysisText = question.analysisText
        questionTextEdited = question.questionText != Self.joined(loaded, kind: .question)
        analysisTextEdited = question.analysisText != Self.joined(loaded, kind: .analysis)
        causeTags = question.causeTags
        includesFifthChoice = question.answerChoices.contains("E")
        correctChoice = question.correctChoice
        savedClipLetters = question.choiceClipLetters
        choiceClips = [:]
        choiceClipsEdited = false
        mastery = question.mastery
        pages = loaded
        isNew = false
        originalPaths = Set(loaded.map(\.relativePath))
        baseline = DraftFingerprint(
            module: question.module,
            subtype: question.subtype,
            questionText: question.questionText,
            analysisText: question.analysisText,
            causeTags: question.causeTags,
            includesFifthChoice: question.answerChoices.contains("E"),
            correctChoice: question.correctChoice,
            choiceClipLetters: question.choiceClipLetters.sorted(),
            mastery: question.mastery,
            pages: Self.fingerprints(for: loaded)
        )
    }

    mutating func sanitizeSelection() {
        if let subtype, !module.subtypes.contains(subtype) {
            self.subtype = nil
        }
        let allowed = Set(CauseTagLibrary.presets(for: module))
        causeTags.removeAll { CauseTagLibrary.isBuiltIn($0) && !allowed.contains($0) }
    }

    mutating func applyRecognition(pageID: UUID, text: String?, appendIfEdited: Bool) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        let cleaned = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        pages[index].isRecognizing = false
        pages[index].recognizedText = cleaned
        pages[index].recognitionFailed = cleaned.isEmpty
        let kind = pages[index].kind
        if !isEdited(kind) {
            setText(kind, joinedText(kind))
        } else if appendIfEdited, !cleaned.isEmpty {
            setText(kind, Self.append(currentText(kind), cleaned))
        }
    }

    mutating func markRecognizing(pageID: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        pages[index].isRecognizing = true
        pages[index].recognitionFailed = false
    }

    mutating func remove(pageID: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        let kind = pages[index].kind
        pages.remove(at: index)
        renumber(kind)
        if !isEdited(kind) {
            setText(kind, joinedText(kind))
        }
    }

    mutating func move(pageID: UUID, earlier: Bool) {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        let kind = pages[index].kind
        var siblings = pages.indices
            .filter { pages[$0].kind == kind }
            .sorted { pages[$0].order < pages[$1].order }
        guard let position = siblings.firstIndex(of: index) else { return }
        let target = earlier ? position - 1 : position + 1
        guard siblings.indices.contains(target) else { return }
        siblings.swapAt(position, target)
        for (order, pageIndex) in siblings.enumerated() {
            pages[pageIndex].order = order
        }
        if !isEdited(kind) {
            setText(kind, joinedText(kind))
        }
    }

    func fingerprint() -> DraftFingerprint {
        DraftFingerprint(
            module: module,
            subtype: subtype,
            questionText: questionText,
            analysisText: analysisText,
            causeTags: causeTags,
            includesFifthChoice: includesFifthChoice,
            correctChoice: correctChoice,
            choiceClipLetters: choiceClipsEdited ? choiceClips.keys.sorted() : savedClipLetters.sorted(),
            mastery: mastery,
            pages: Self.fingerprints(for: pages)
        )
    }

    func joinedText(_ kind: PageKind) -> String {
        Self.joined(pages, kind: kind)
    }

    private func isEdited(_ kind: PageKind) -> Bool {
        kind == .question ? questionTextEdited : analysisTextEdited
    }

    private func currentText(_ kind: PageKind) -> String {
        kind == .question ? questionText : analysisText
    }

    private mutating func setText(_ kind: PageKind, _ text: String) {
        switch kind {
        case .question: questionText = text
        case .analysis: analysisText = text
        }
    }

    private mutating func renumber(_ kind: PageKind) {
        let siblings = pages.indices
            .filter { pages[$0].kind == kind }
            .sorted { pages[$0].order < pages[$1].order }
        for (order, pageIndex) in siblings.enumerated() {
            pages[pageIndex].order = order
        }
    }

    private static func joined(_ pages: [DraftPage], kind: PageKind) -> String {
        pages
            .filter { $0.kind == kind }
            .sorted { $0.order < $1.order }
            .map { $0.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func fingerprints(for pages: [DraftPage]) -> [PageFingerprint] {
        pages
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return lhs.kind == .question }
                return lhs.order < rhs.order
            }
            .map {
                PageFingerprint(
                    id: $0.id,
                    kind: $0.kind,
                    order: $0.order,
                    relativePath: $0.relativePath,
                    recognizedText: $0.recognizedText
                )
            }
    }

    static func append(_ base: String, _ extra: String) -> String {
        let extra = extra.trimmingCharacters(in: .whitespacesAndNewlines)
        if extra.isEmpty { return base }
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return extra }
        return trimmed + "\n\n" + extra
    }
}
