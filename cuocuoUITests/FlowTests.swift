import XCTest

final class FlowTests: XCTestCase {
    func testReviewASeededQuestion() {
        let app = XCUIApplication()
        app.launchArguments = ["-seed-sample"]
        app.launch()

        let today = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "今天要看")).firstMatch
        if !today.waitForExistence(timeout: 8) {
            XCTFail(app.debugDescription)
            return
        }
        attach(named: "01-home")
        today.tap()

        let start = app.buttons["开始看"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        attach(named: "02-today")
        start.tap()

        let choice = app.buttons["选项 B"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        attach(named: "03-question")
        choice.tap()

        let known = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "已经会了")).firstMatch
        XCTAssertTrue(known.waitForExistence(timeout: 5))
        attach(named: "04-after-answer")
        known.tap()

        let nextChoice = app.buttons["选项 C"]
        if nextChoice.waitForExistence(timeout: 4) {
            attach(named: "05-next-question")
            nextChoice.tap()
            let again = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "还会")).firstMatch
            XCTAssertTrue(again.waitForExistence(timeout: 4))
            again.tap()
        }

        let done = app.buttons["完成"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        attach(named: "06-done")
    }

    private func attach(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
