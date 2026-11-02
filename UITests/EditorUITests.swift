import XCTest

final class EditorUITests:XCTestCase {
    override func setUpWithError()throws {XCUIDevice.shared.orientation = .landscapeLeft}
    func testFramePanelClipboardAndUndo() throws {
        let app = XCUIApplication(); app.launchArguments = ["--reference-practice"]; app.launch()
        let navigator = app.otherElements["FrameNavigator"]
        XCTAssertTrue(navigator.waitForExistence(timeout: 10))
        app.buttons["РЕД. КАДР"].tap()
        let panel = app.otherElements["FrameToolsPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let paste = app.buttons["frame_ops_paste"]
        XCTAssertFalse(paste.isEnabled)
        app.buttons["frame_ops_copy"].tap()
        XCTAssertTrue(paste.isEnabled)
        paste.tap()
        XCTAssertEqual(navigator.value as? String, "1 / 3")
        XCTAssertTrue(panel.exists)
        app.buttons["ОТМЕНА"].tap()
        XCTAssertEqual(navigator.value as? String, "1 / 2")
        app.buttons["frame_ops_del"].tap()
        XCTAssertEqual(navigator.value as? String, "1 / 1")
        XCTAssertFalse(app.buttons["frame_ops_del"].isEnabled)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Original frame tools panel with clipboard and last-frame guard"
        screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["РЕД. КАДР"].tap()
        XCTAssertFalse(panel.exists)
    }
    func testCatalogFoldersBackAndCloseWithoutInsertion() throws {
        let app = XCUIApplication(); app.launchArguments = ["--reference-practice"]; app.launch()
        XCTAssertTrue(app.buttons["ДОБАВИТЬ"].waitForExistence(timeout: 10))
        app.buttons["ДОБАВИТЬ"].tap()
        let pack = app.collectionViews.cells["catalog-pack-newstickman"]
        XCTAssertTrue(pack.waitForExistence(timeout: 5)); pack.tap()
        let folder = app.collectionViews.cells["catalog-folder-Weapons"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5)); folder.tap()
        XCTAssertTrue(app.collectionViews.cells["catalog-item-newstickman:axe"].waitForExistence(timeout: 5))
        app.buttons["Назад по каталогу"].tap()
        XCTAssertTrue(app.collectionViews.cells["catalog-folder-Weapons"].waitForExistence(timeout: 5))
        app.buttons["Назад по каталогу"].tap()
        XCTAssertTrue(app.collectionViews.cells["catalog-pack-jungle"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Original pack covers and in-editor catalog"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Закрыть каталог"].tap()
        XCTAssertFalse(app.collectionViews.firstMatch.exists)
        app.buttons["ДОБАВИТЬ"].tap(); app.buttons["ДОБАВИТЬ"].tap()
        XCTAssertFalse(app.collectionViews.firstMatch.exists)
    }
    func testOriginalATSWithEmbeddedArtwork()throws {
        let app=XCUIApplication();app.launchArguments=["--reference-practice"];app.launch()
        let navigator=app.otherElements["FrameNavigator"]
        XCTAssertTrue(navigator.waitForExistence(timeout:10))
        // The archived source has two keyframes; onboarding adds practice frames
        // at runtime. This import test must match the archive, not the lesson's UI.
        XCTAssertEqual(navigator.value as? String,"1 / 2")
        XCTAssertFalse(app.alerts.firstMatch.exists,"Original ATS and its nested ATI must load without an import error")
        let image=XCTAttachment(screenshot:XCUIScreen.main.screenshot());image.name="Entire display — original practice ATS with embedded ATI artwork";image.lifetime = .keepAlways;add(image)
        let hierarchy=XCTAttachment(string:app.debugDescription);hierarchy.name="Original project accessibility geometry";hierarchy.lifetime = .keepAlways;add(hierarchy)
    }
    func testInsertCharacterCreateFrameAndPlayback() throws {
        let app=XCUIApplication()
        app.launch()
        let insert=app.buttons["ДОБАВИТЬ"]
        XCTAssertTrue(insert.waitForExistence(timeout:10))
        insert.tap()
        app.collectionViews.cells["catalog-pack-jungle"].tap()
        let item=app.collectionViews.cells.matching(identifier:"catalog-item-jungle:lion").firstMatch
        XCTAssertTrue(item.waitForExistence(timeout:5))
        item.tap()
        app.buttons["Закрыть каталог"].tap()
        app.buttons["Следующий кадр"].tap()
        let navigator=app.otherElements["FrameNavigator"]
        XCTAssertEqual(navigator.value as? String,"2 / 2")
        app.buttons["ПУСК"].tap()
        XCTAssertTrue(app.otherElements["PreviewCanvas"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["ДОБАВИТЬ"].isHittable)
        app.buttons["PreviewClose"].tap()
        XCTAssertTrue(app.buttons["ДОБАВИТЬ"].waitForExistence(timeout:5))
        let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        attachment.name="Editor after character insertion and frame playback"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
