import XCTest

final class EditorUITests:XCTestCase {
    override func setUpWithError()throws {XCUIDevice.shared.orientation = .landscapeLeft}
    func testSharedMySpritesFolderPinnedInEveryPack() throws {
        let app=XCUIApplication();app.launchArguments=["--reference-practice"];app.launch()
        XCTAssertTrue(app.buttons["ДОБАВИТЬ"].waitForExistence(timeout:10));app.buttons["ДОБАВИТЬ"].tap()
        app.collectionViews.cells["catalog-pack-jungle"].tap()
        XCTAssertEqual(app.collectionViews.cells.element(boundBy:0).identifier,"catalog-my-sprites")
        app.collectionViews.cells["catalog-my-sprites"].tap();XCTAssertTrue(app.buttons["ATIImport"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["ATIImport"].isHittable)
        app.buttons["Назад по каталогу"].tap();app.buttons["Назад по каталогу"].tap()
        app.collectionViews.cells["catalog-pack-newstickman"].tap();XCTAssertEqual(app.collectionViews.cells.element(boundBy:0).identifier,"catalog-my-sprites")
        app.collectionViews.cells["catalog-my-sprites"].tap();XCTAssertTrue(app.buttons["ATIImport"].isHittable)
        let image=XCTAttachment(screenshot:XCUIScreen.main.screenshot());image.name="Pinned shared My sprites folder and ATI import button";image.lifetime = .keepAlways;add(image)
        app.buttons["Закрыть каталог"].tap()
    }
    func testDetachThroughOriginalPropertiesAndUndo() throws {
        let app=XCUIApplication();app.launchArguments=["--reference-attached"];app.launch()
        XCTAssertTrue(app.buttons["РЕДАКТ."].waitForExistence(timeout:10));app.buttons["РЕДАКТ."].tap()
        let detach=app.buttons["prop_detach"];XCTAssertTrue(detach.waitForExistence(timeout:5));detach.tap()
        XCTAssertFalse(detach.exists)
        app.buttons["ОТМЕНА"].tap();app.buttons["unit-list-0"].tap()
        XCTAssertTrue(detach.waitForExistence(timeout:5))
        let image=XCTAttachment(screenshot:XCUIScreen.main.screenshot());image.name="Original unit properties with detach restored by undo";image.lifetime = .keepAlways;add(image)
    }
    func testManualAssetStateAndAnimationSettings() throws {
        let app=XCUIApplication();app.launchArguments=["--reference-animation"];app.launch()
        XCTAssertTrue(app.buttons["РЕДАКТ."].waitForExistence(timeout:10));app.buttons["РЕДАКТ."].tap();app.buttons["prop_set_states"].tap()
        app.buttons["asset-state-1"].tap();XCTAssertTrue(app.buttons["asset-state-1"].isSelected)
        app.buttons["animation_cogs"].tap();let enabled=app.switches["AssetAnimationEnabled"];XCTAssertTrue(enabled.waitForExistence(timeout:5));enabled.tap();app.switches["AssetAnimationReverse"].tap();app.buttons["AssetAnimationApply"].tap()
        let image=XCTAttachment(screenshot:XCUIScreen.main.screenshot());image.name="Manual sprite states and automatic animation entry";image.lifetime = .keepAlways;add(image)
    }
    func testOriginalBackgroundPickerAndSelection() throws {
        let app=XCUIApplication();app.launchArguments=["--reference-practice"];app.launch()
        XCTAssertTrue(app.buttons["ДОБАВИТЬ"].waitForExistence(timeout:10))
        // The unlabelled first toolbar button opens the project drawer.
        app.buttons["ProjectMenu"].tap();app.buttons["Фон"].tap()
        XCTAssertTrue(app.tables.cells["background-pack-common"].waitForExistence(timeout:5))
        let background=app.collectionViews.cells["background-common:bank"];XCTAssertTrue(background.waitForExistence(timeout:5));background.tap()
        let image=XCTAttachment(screenshot:XCUIScreen.main.screenshot());image.name="Original two-column background library";image.lifetime = .keepAlways;add(image)
        app.buttons["Закрыть фоны"].tap();XCTAssertFalse(app.collectionViews.firstMatch.exists)
    }
    func testBasePointTransformHandlesAndSingleGestureUndo() throws {
        let app = XCUIApplication(); app.launchArguments = ["--reference-practice"]; app.launch()
        XCTAssertTrue(app.buttons["ДОБАВИТЬ"].waitForExistence(timeout: 10))
        app.buttons["ДОБАВИТЬ"].tap(); app.collectionViews.cells["catalog-pack-jungle"].tap()
        app.collectionViews.cells["catalog-item-jungle:lion"].tap(); app.buttons["Закрыть каталог"].tap()
        let canvas = app.otherElements["SceneCanvas"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let scale = app.buttons["SpriteScale"], rotate = app.buttons["SpriteRotate"], move = app.buttons["SpriteMove"]
        XCTAssertTrue(scale.waitForExistence(timeout: 5)); XCTAssertTrue(rotate.isHittable); XCTAssertTrue(move.isHittable)
        let initialScale = scale.value as? String
        let from = scale.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: -55, dy: 45)))
        XCTAssertNotEqual(scale.value as? String, initialScale)
        app.buttons["ОТМЕНА"].tap(); canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(scale.value as? String, initialScale, "One undo restores the whole scale gesture")
        let angle = rotate.value as? String
        let rotationStart = rotate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        rotationStart.press(forDuration: 0.1, thenDragTo: rotationStart.withOffset(CGVector(dx: 55, dy: 65)))
        XCTAssertNotEqual(rotate.value as? String, angle)
        let position = move.value as? String
        let moveStart = move.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        moveStart.press(forDuration: 0.1, thenDragTo: moveStart.withOffset(CGVector(dx: 35, dy: -30)))
        XCTAssertNotEqual(move.value as? String, position)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = "Original rotate scale move handles after gestures"; image.lifetime = .keepAlways; add(image)
    }
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
        XCTAssertTrue(app.buttons["PreviewReplay"].waitForExistence(timeout: 5))
        let preview = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); preview.name = "Separate preview with explicit close and replay"; preview.lifetime = .keepAlways; add(preview)
        app.buttons["PreviewClose"].tap()
        XCTAssertTrue(app.buttons["ДОБАВИТЬ"].waitForExistence(timeout:5))
        let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        attachment.name="Editor after character insertion and frame playback"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
