import XCTest

/// Drives the real screen. The save file persists between runs, so each test starts from whichever
/// of the two launch states it finds. Board taps sweep a grid, because the board is drawn and which
/// corners are legal depends on the random seed.
final class GameFlowTests: XCTestCase {
    private let settlementPrompt = "Tap a glowing corner to place a settlement."
    private let roadPrompt = "Tap a dashed edge next to it to lay a road."
    private let rollPrompt = "Roll the dice to start your turn."

    /// Chooses from the menu in the header. On the handover screen there is no menu, so it passes that first.
    private func chooseFromMenu(_ app: XCUIApplication, _ item: String) {
        let handover = app.buttons["handover"]
        if handover.exists { handover.tap() }
        #if os(macOS)
        app.menuButtons["menu"].tap()
        app.menuItems[item].tap()
        #else
        app.buttons["menu"].tap()
        app.buttons[item].tap()
        #endif
    }

    private func openNewGameSheet(_ app: XCUIApplication) {
        let start = app.buttons["Start game"]
        if !start.waitForExistence(timeout: 5) {
            chooseFromMenu(app, "New game")
            XCTAssertTrue(start.waitForExistence(timeout: 5))
        }
    }

    private func startNewGame(_ app: XCUIApplication) {
        openNewGameSheet(app)
        app.buttons["Start game"].tap()
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
        chooseFromMenu(app, "Preview win")
        XCTAssertTrue(app.buttons["Back to the game"].waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.buttons["Back to the game"].waitForExistence(timeout: 1))
    }
    #endif

    private func assertSquareBox(_ app: XCUIApplication, _ id: String, reads label: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let box = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(box.exists, "no box \(id)", file: file, line: line)
        XCTAssertEqual(box.frame.width, box.frame.height, accuracy: 1, "\(id) is not square", file: file, line: line)
        if let label { XCTAssertEqual(box.label, label, file: file, line: line) }
    }

    func testResourcesAreSquareBoxesAndTheHandStaysOnScreen() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)
        XCTAssertTrue(app.staticTexts["status"].waitForExistence(timeout: 5))
        for resource in ["timber", "clay", "wool", "grain", "ore"] {
            assertSquareBox(app, "hold \(resource)", reads: "0 \(resource)")
        }
        XCTAssertTrue(app.descendants(matching: .any)["hold timber"].firstMatch.isHittable)
        keepScreenshot(app, named: "resource boxes")
    }

    func testTheLogStaysInsideTheTabArea() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)
        let log = app.scrollViews["log"]
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(log.frame.maxY, app.windows.firstMatch.frame.maxY)
        XCTAssertGreaterThanOrEqual(log.frame.minY, app.buttons["tab Log"].frame.maxY)
    }

    func testPreviewWinClosesWithBackToTheGame() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)
        chooseFromMenu(app, "Preview win")
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
        openNewGameSheet(app)
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
                if seen.insert("offer builder").inserted {
                    XCTAssertTrue(app.descendants(matching: .any)["bank timber"].firstMatch.exists, "the bank is not in the Trade tab")
                    app.buttons["Offer a trade to players…"].tap()
                    assertSquareBox(app, "give timber")
                    assertSquareBox(app, "want ore")
                    keepScreenshot(app, named: "offer builder")
                    app.buttons["Back"].tap()
                }
                XCTAssertTrue(app.descendants(matching: .any)["hold timber"].firstMatch.isHittable, "the hand is off screen")
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
        XCTAssertFalse(app.buttons["bank give"].isEnabled, "the bank dropdown is enabled before the roll")
        XCTAssertFalse(app.buttons["bank get"].isEnabled, "the bank dropdown is enabled before the roll")
        app.buttons["Roll dice"].tap()
        let moved = NSPredicate { _, _ in self.status(app) != self.rollPrompt }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)
    }

    /// Plays one moment forward, whatever the game is asking for. A handover is left for the caller.
    private func playOneStep(_ app: XCUIApplication) {
        let now = status(app)
        let decline = app.buttons["Decline"], rollFirst = app.buttons["Roll for first"]
        if now == settlementPrompt || now == roadPrompt || now == "Tap a tile to move the robber there." {
            sweepBoard(app, while: now)
        } else if now == rollPrompt {
            app.buttons["Roll dice"].tap()
        } else if now == "Build, trade, or end your turn." {
            app.buttons["End turn"].tap()
        } else if now.hasPrefix("Steal a card") {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Steal from'")).firstMatch.tap()
        } else if now.contains("must give up half") {
            let plus = app.buttons.matching(NSPredicate(format: "label == '+' AND enabled == true")).firstMatch
            while plus.exists { plus.tap() }
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Discard'")).firstMatch.tap()
        } else if rollFirst.exists, rollFirst.isEnabled {
            rollFirst.tap()
        } else if decline.exists, decline.isEnabled {
            decline.tap()
        } else {
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// The owner's complaint: things move when they should not. Every fixed control is measured at
    /// each new moment of a real game, through setup, rolls, a build mode and AI turns.
    func testControlsNeverMove() {
        let app = XCUIApplication()
        app.launch()
        startNewGame(app)
        XCTAssertTrue(app.staticTexts["status"].waitForExistence(timeout: 5))

        var places: [String: CGRect] = [:], moments = Set<String>()
        func measure() {
            let moment = status(app)
            guard moments.insert(moment).inserted else { return }
            let roll = app.buttons["Roll for first"].exists ? app.buttons["Roll for first"] : app.buttons["Roll dice"]
            let fixed: [(String, XCUIElement)] = [
                ("status", app.staticTexts["status"]),
                ("header", app.staticTexts["header"]),
                ("hand", app.descendants(matching: .any)["hold timber"].firstMatch),
                ("roll", roll),
                ("end turn", app.buttons["End turn"]),
                ("road", app.buttons["Road"]),
                ("tabs", app.buttons["tab Trade"]),
                ("log tab", app.buttons["tab Log"]),
            ]
            for (name, element) in fixed {
                XCTAssertTrue(element.exists, "\(name) is gone at: \(moment)")
                let frame = element.frame
                if let known = places[name] {
                    if name == "status" {
                        // The text is centred in a fixed slot, so its own edges follow its length; its centre must not move.
                        XCTAssertEqual(known.midX, frame.midX, accuracy: 1, "\(name) moved at: \(moment)")
                        XCTAssertEqual(known.midY, frame.midY, accuracy: 1, "\(name) moved at: \(moment)")
                    } else {
                        XCTAssertEqual(known.minX, frame.minX, accuracy: 1, "\(name) moved at: \(moment)")
                        XCTAssertEqual(known.minY, frame.minY, accuracy: 1, "\(name) moved at: \(moment)")
                        XCTAssertEqual(known.height, frame.height, accuracy: 1, "\(name) changed height at: \(moment)")
                    }
                } else {
                    places[name] = frame
                }
                XCTAssertTrue(element.isHittable, "\(name) is off screen at: \(moment)")
            }
        }

        let end = Date().addingTimeInterval(240)
        var builtMode = false
        while Date() < end, moments.count < 12 {
            measure()
            if status(app) == "Build, trade, or end your turn.", !builtMode, app.buttons["Road"].isEnabled {
                builtMode = true
                app.buttons["Road"].tap()
                measure()
                app.buttons["Road"].tap()
            }
            playOneStep(app)
        }
        print("moments measured: \(moments.sorted())")
        XCTAssertGreaterThanOrEqual(moments.count, 5, "only saw: \(moments.sorted())")
    }

    /// Crimson and Cobalt share the device: neither sees the other's cards until they tap the button.
    func testHandoverHidesTheNextHand() {
        let app = XCUIApplication()
        app.launch()
        openNewGameSheet(app)
        app.segmentedControls.element(boundBy: 2).buttons["Human"].tap()
        app.buttons["Start game"].tap()
        XCTAssertTrue(app.staticTexts["status"].waitForExistence(timeout: 5))

        let handover = app.buttons["handover"], hand = app.descendants(matching: .any)["hold timber"].firstMatch
        let end = Date().addingTimeInterval(300)
        while !handover.exists, Date() < end { playOneStep(app) }
        XCTAssertTrue(handover.exists, "no handover in five minutes")
        keepScreenshot(app, named: "handover")
        XCTAssertFalse(hand.exists, "a hand shows behind the handover")
        XCTAssertFalse(app.buttons["End turn"].exists, "the game shows behind the handover")

        handover.tap()
        XCTAssertTrue(hand.waitForExistence(timeout: 2), "no hand after the handover")
        keepScreenshot(app, named: "after handover")

        app.terminate()
        app.launch()
        XCTAssertTrue(handover.waitForExistence(timeout: 5), "reopening showed the game straight away")
        XCTAssertFalse(hand.exists)
    }
}
