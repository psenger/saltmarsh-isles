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

    // @ui: The win screen is hidden at load
    func testTheWinScreenIsHiddenAtLoad() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["status"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["See the board"].exists)
        XCTAssertFalse(app.buttons["Back to the game"].exists)
    }

    #if os(macOS)
    // @ui: Escape closes the win screen
    func testEscapeClosesTheWinScreen() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)
        app.buttons["Preview win"].tap()
        XCTAssertTrue(app.buttons["Back to the game"].waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.buttons["Back to the game"].waitForExistence(timeout: 1))
    }
    #endif

    func testTheLogScrollsInsideAFixedBox() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)
        let log = app.scrollViews["log"]
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(log.frame.height, 150)
    }

    func testPreviewWinClosesWithBackToTheGame() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)
        app.buttons["Preview win"].tap()
        let back = app.buttons["Back to the game"]
        XCTAssertTrue(back.waitForExistence(timeout: 2))
        keepScreenshot(app, named: "preview win")
        back.tap()
        XCTAssertFalse(back.waitForExistence(timeout: 1))
        XCTAssertEqual(app.staticTexts["header"].label, "Crimson · first roll")
    }

    func testRelaunchResumesTheGame() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)
        XCTAssertTrue(app.staticTexts["header"].waitForExistence(timeout: 5))
        let header = app.staticTexts["header"].label
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["header"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["header"].label, header)
        XCTAssertFalse(app.buttons["Start game"].exists)
    }

    func testNewGameSheetOffersEverySeat() {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["Start game"]
        if !start.waitForExistence(timeout: 3) { app.buttons["New game"].tap() }
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        keepScreenshot(app, named: "new game sheet")
        XCTAssertTrue(app.staticTexts["Crimson"].exists)
        XCTAssertTrue(app.staticTexts["Amber"].exists)
        XCTAssertFalse(app.staticTexts["Ivory"].exists)
    }

    /// Plays Crimson for three minutes, never building, so the hand grows into discards and sevens
    /// bring the robber. Fails if any moment offers the human no way forward.
    func testHumanTurnsNeverGetStuck() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)

        var turns = 0, last = "", lastChange = Date(), seen = Set<String>()
        func once(_ name: String) {
            if seen.insert(name).inserted { keepScreenshot(app, named: name) }
        }
        let end = Date().addingTimeInterval(180)
        while Date() < end {
            let now = status(app)
            if now != last { last = now; lastChange = Date() }
            XCTAssertLessThan(Date().timeIntervalSince(lastChange), 120, "stuck on: \(now)")

            if now == settlementPrompt || now == roadPrompt {
                sweepBoard(app, while: now)
            } else if now == rollPrompt {
                app.buttons["Roll dice"].tap()
                turns += 1
            } else if now == "Build, trade, or end your turn." {
                once("main")
                app.buttons["End turn"].tap()
            } else if now == "Tap a tile to move the robber there." {
                once("robber")
                sweepBoard(app, while: now)
            } else if now.hasPrefix("Steal a card") {
                once("steal")
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Steal from'")).firstMatch.tap()
            } else if now.contains("must give up half") {
                once("discard")
                let plus = app.buttons.matching(NSPredicate(format: "label == '+' AND enabled == true")).firstMatch
                while plus.exists { plus.tap() }
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Discard'")).firstMatch.tap()
            } else if app.buttons["Roll for first"].exists, app.buttons["Roll for first"].isEnabled {
                app.buttons["Roll for first"].tap()
            } else if app.buttons["Decline"].exists, app.buttons["Decline"].isEnabled {
                app.buttons["Decline"].tap()
            } else {
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
        XCTAssertGreaterThan(turns, 2, "only \(turns) human turns in three minutes")
        print("human turns: \(turns), moments seen: \(seen.sorted())")
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
