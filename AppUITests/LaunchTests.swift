import XCTest

final class LaunchTests: XCTestCase {
    func testLaunchShowsTitle() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Saltmarsh Isles"].waitForExistence(timeout: 10))
    }
}
