import SwiftData
import XCTest

@testable import cuocuo

final class LogicTests: XCTestCase {
    func testUnmasteredWithoutDateIsDueToday() {
        XCTAssertTrue(ReviewSchedule.isDue(mastery: .unmastered, nextReviewAt: nil, on: Date()))
    }

    func testMasteredIsNotDue() {
        XCTAssertFalse(ReviewSchedule.isDue(mastery: .mastered, nextReviewAt: nil, on: Date()))
        XCTAssertFalse(ReviewSchedule.isDue(mastery: .mastered, nextReviewAt: Date(), on: Date()))
    }

    func testFutureReviewIsNotDueUntilThatDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 21))!
        let later = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6))!
        XCTAssertFalse(ReviewSchedule.isDue(mastery: .unmastered, nextReviewAt: later, on: today, calendar: calendar))
        XCTAssertTrue(ReviewSchedule.isDue(mastery: .unmastered, nextReviewAt: later, on: later, calendar: calendar))
    }

    func testAgainIsThreeMorningsLater() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 23))!
        let next = ReviewSchedule.nextDate(after: evening, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: next)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 10)
        XCTAssertEqual(parts.day, 6)
        XCTAssertEqual(parts.hour, 0)
    }

    func testSaveNeedsQuestionPageNotAnalysis() {
        var draft = QuestionDraft(module: .judgment)
        XCTAssertFalse(draft.canSave)
        draft.analysisText = "规律是旋转"
        XCTAssertFalse(draft.canSave)
        draft.pages = [samplePage(kind: .question, order: 0, text: "图形")]
        XCTAssertTrue(draft.canSave)
    }

    func testSwitchingModuleDropsOtherModuleTags() {
        var draft = QuestionDraft(module: .judgment)
        draft.causeTags = ["图形规律未识别", "审题偏差"]
        draft.subtype = "图形推理"
        draft.module = .quantitative
        draft.sanitizeSelection()
        XCTAssertEqual(draft.causeTags, ["审题偏差"])
        XCTAssertNil(draft.subtype)
    }

    func testRecognitionJoinsPagesInOrderUntilEdited() {
        var draft = QuestionDraft(module: .quantitative)
        let first = UUID()
        let second = UUID()
        draft.pages = [
            samplePage(id: first, kind: .question, order: 0, text: ""),
            samplePage(id: second, kind: .question, order: 1, text: "")
        ]
        draft.pages[0].isRecognizing = true
        draft.pages[1].isRecognizing = true
        draft.applyRecognition(pageID: second, text: "第二页", appendIfEdited: true)
        draft.applyRecognition(pageID: first, text: "第一页", appendIfEdited: true)
        XCTAssertEqual(draft.questionText, "第一页\n\n第二页")

        draft.questionText = "我改过"
        draft.questionTextEdited = true
        draft.applyRecognition(pageID: first, text: "新的第一页", appendIfEdited: true)
        XCTAssertEqual(draft.questionText, "我改过\n\n新的第一页")
    }

    func testChoiceClipPathLinesUpWithLetter() {
        let question = WrongQuestion(
            id: UUID(),
            module: .judgment,
            subtype: "图形推理",
            questionText: "",
            analysisText: "",
            causeTags: [],
            mastery: .unmastered,
            createdAt: Date(),
            updatedAt: Date()
        )
        question.choiceClipLetters = ["A", "B", "C", "D"]
        question.choiceClipPaths = ["a.jpg", "b.jpg", "c.jpg", "d.jpg"]
        XCTAssertEqual(question.choiceClipPath(for: "C"), "c.jpg")
        XCTAssertNil(question.choiceClipPath(for: "E"))
    }

    func testEmptyChoiceListFallsBackToABCD() {
        XCTAssertEqual(ChoiceOptions.normalized([]), ["A", "B", "C", "D"])
        XCTAssertEqual(ChoiceOptions.normalized(["C", "A", "E"]), ["A", "C", "E"])
    }

    func testDueQuestionsAreOldestFirst() throws {
        let container = try ModelContainer(
            for: WrongQuestion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let newer = WrongQuestion(
            id: UUID(),
            module: .judgment,
            subtype: nil,
            questionText: "新",
            analysisText: "",
            causeTags: [],
            mastery: .unmastered,
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date()
        )
        let older = WrongQuestion(
            id: UUID(),
            module: .judgment,
            subtype: nil,
            questionText: "旧",
            analysisText: "",
            causeTags: [],
            mastery: .unmastered,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date()
        )
        let later = WrongQuestion(
            id: UUID(),
            module: .judgment,
            subtype: nil,
            questionText: "以后",
            analysisText: "",
            causeTags: [],
            mastery: .unmastered,
            nextReviewAt: Date().addingTimeInterval(86_400 * 5),
            createdAt: Date(timeIntervalSince1970: 50),
            updatedAt: Date()
        )
        context.insert(newer)
        context.insert(older)
        context.insert(later)
        let due = ReviewSchedule.dueQuestions(from: [newer, older, later])
        XCTAssertEqual(due.map(\.questionText), ["旧", "新"])
    }
}

private func samplePage(id: UUID = UUID(), kind: PageKind, order: Int, text: String) -> DraftPage {
    DraftPage(
        id: id,
        kind: kind,
        order: order,
        relativePath: "\(id).jpg",
        recognizedText: text,
        isRecognizing: false,
        recognitionFailed: text.isEmpty
    )
}
