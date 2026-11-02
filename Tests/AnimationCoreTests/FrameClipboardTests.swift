import XCTest
@testable import AnimationCore

final class FrameClipboardTests: XCTestCase {
    private func frame(_ id: Int) -> SceneFrame { SceneFrame(id: id, units: [], attributes: ["marker": String(id)]) }
    func testPasteAtFirstFrameInsertsBeforeAndDoesNotMutateSnapshot() {
        var document = SceneDocument(width: 640, height: 480, interframes: 4, frames: [frame(7), frame(19)], attributes: [:])
        let snapshot = [document.frames[1]]
        XCTAssertEqual(FrameClipboard.paste(snapshot, into: &document, currentIndex: 0), 0..<1)
        XCTAssertEqual(document.frames.map(\.id), [20, 7, 19])
        XCTAssertEqual(document.frames[0].attributes["marker"], "19")
        document.frames[0].attributes["marker"] = "edited"
        XCTAssertEqual(snapshot[0].attributes["marker"], "19")
    }
    func testBulkPasteAfterLaterFramePreservesOrderAndGeneratesUniqueIDs() {
        var document = SceneDocument(width: 640, height: 480, interframes: 4, frames: [frame(7), frame(19), frame(3)], attributes: [:])
        let snapshot = [frame(7), frame(3)]
        XCTAssertEqual(FrameClipboard.paste(snapshot, into: &document, currentIndex: 1), 2..<4)
        XCTAssertEqual(document.frames.map(\.id), [7, 19, 20, 21, 3])
        XCTAssertEqual(document.frames.map { $0.attributes["marker"]! }, ["7", "19", "7", "3", "3"])
        XCTAssertNil(FrameClipboard.paste([], into: &document, currentIndex: 1))
        XCTAssertNil(FrameClipboard.paste(snapshot, into: &document, currentIndex: -1))
        XCTAssertEqual(document.frames.count, 5)
    }
}
