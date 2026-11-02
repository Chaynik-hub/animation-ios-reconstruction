import XCTest

final class EditorUITests:XCTestCase {
    func testInsertCharacterCreateFrameAndPlayback() throws {
        let app=XCUIApplication()
        app.launch()
        let insert=app.buttons["ДОБАВИТЬ"]
        XCTAssertTrue(insert.waitForExistence(timeout:10))
        insert.tap()
        let item=app.collectionViews.cells.firstMatch
        XCTAssertTrue(item.waitForExistence(timeout:5))
        item.tap()
        app.buttons["+"].tap()
        XCTAssertTrue(app.staticTexts["2 /\n2"].waitForExistence(timeout:5))
        app.buttons["ПУСК"].tap()
        app.buttons["ПУСК"].tap()
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name="Editor after character insertion and frame playback"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
