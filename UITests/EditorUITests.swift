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
        app.buttons["Следующий кадр"].tap()
        let navigator=app.otherElements["FrameNavigator"]
        XCTAssertEqual(navigator.value as? String,"2 / 2")
        app.buttons["ПУСК"].tap()
        XCTAssertTrue(app.otherElements["PreviewCanvas"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["ДОБАВИТЬ"].isHittable)
        app.coordinate(withNormalizedOffset:CGVector(dx:0.001,dy:0.5)).press(forDuration:0.1,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)))
        XCTAssertTrue(app.buttons["ДОБАВИТЬ"].waitForExistence(timeout:5))
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name="Editor after character insertion and frame playback"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
