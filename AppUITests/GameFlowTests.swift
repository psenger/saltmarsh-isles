import XCTest

/// Drives the real screen. The save file persists between runs, so each test starts from whichever
/// of the two launch states it finds. Board taps sweep a grid, because the board is drawn and which
/// corners are legal depends on the random seed.
final class GameFlowTests: XCTestCase {
    private let settlementPrompt = "Tap a glowing corner to place a settlement."
    private let roadPrompt = "Tap a dashed edge next to it to lay a road."
    private let rollPrompt = "Roll the dice to start your turn."

    private func startNewGame(_ app: XCUIApplication) {
        let start = app.buttons["Start game"]
        if !start.waitForExistence(timeout: 5) {
            app.buttons["New game"].tap()
            XCTAssertTrue(start.waitForExistence(timeout: 5))
        }
        start.tap()
    }

    private func status(_ app: XCUIApplication) -> String {
        let element = app.staticTexts["status"]
        return element.exists ? element.label : ""
    }

    /// Taps across the board until the status line moves on from `prompt`.
    private func sweepBoard(_ app: XCUIApplication, while prompt: String) {
        let board = app.descendants(matching: .any)["board"]
        for row in stride(from: 0.1, through: 0.9, by: 0.05) {
            for column in stride(from: 0.1, through: 0.9, by: 0.05) {
                if status(app) != prompt { return }
                board.coordinate(withNormalizedOffset: CGVector(dx: column, dy: row)).tap()
            }
        }
        XCTFail("no tap on the board moved on from: \(prompt)")
    }

    private func keepScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPlaysThroughSetupToTheFirstRoll() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)

        let deadline = Date().addingTimeInterval(240)
        while status(app) != rollPrompt, Date() < deadline {
            switch status(app) {
            case settlementPrompt: sweepBoard(app, while: settlementPrompt)
            case roadPrompt: sweepBoard(app, while: roadPrompt)
            default:
                let roll = app.buttons["Roll for first"], decline = app.buttons["Decline"]
                if roll.exists, roll.isEnabled {
                    roll.tap()
                } else if decline.exists, decline.isEnabled {       // an AI offered this seat a trade
                    keepScreenshot(app, named: "trade offer")
                    XCTAssertTrue(app.staticTexts["status"].isHittable, "the offer is off screen")
                    decline.tap()
                } else {
                    Thread.sleep(forTimeInterval: 0.3)
                }
            }
        }
        XCTAssertEqual(status(app), rollPrompt)
        keepScreenshot(app, named: "first roll")
        XCTAssertTrue(app.staticTexts["status"].isHittable, "the status line is off screen")
        XCTAssertTrue(app.staticTexts["header"].isHittable, "the header is off screen")
        app.buttons["Roll dice"].tap()
        let moved = NSPredicate { _, _ in self.status(app) != self.rollPrompt }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)
    }
}
