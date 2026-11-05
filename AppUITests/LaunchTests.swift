import XCTest

final class LaunchTests: XCTestCase {
    /// Depending on the saved game, launch opens the game, the handover screen or the new game sheet.
    func testLaunchShowsTheGame() {
        let app = XCUIApplication()
        app.launch()
        let opened = NSPredicate { _, _ in
            app.staticTexts["status"].exists || app.buttons["handover"].exists || app.buttons["Start game"].exists
        }
        wait(for: [XCTNSPredicateExpectation(predicate: opened, object: nil)], timeout: 10)
    }
}
