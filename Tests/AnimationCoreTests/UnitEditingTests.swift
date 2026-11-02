import XCTest
@testable import AnimationCore
final class UnitEditingTests: XCTestCase {
    private func fixture() -> SceneFrame {
        let arm = SceneUnit(name: "arm", joints: [Joint(id: 0, x: 0, y: 0, parent: nil, attributes: ["base":"true"]), Joint(id: 1, x: 100, y: 0, parent: 0, attributes: ["attachable":"master"])], attributes: [:])
        let sword = SceneUnit(name: "sword", joints: [Joint(id: 0, x: 100, y: 0, parent: nil, attributes: ["base":"true", "attachable":"slave", "attached":"arm&1"])], attributes: [:])
        return SceneFrame(id: 0, units: [arm, sword, SceneUnit(name: "other", joints: [], attributes: [:])], attributes: [:])
    }
    func testCopyingAttachedSwordCopiesAssemblyAndRemapsLinks() throws {
        var frame = fixture()
        let copied = UnitEditing.snapshot(in: frame, selected: 1)
        XCTAssertEqual(copied.map(\.name), ["arm", "sword"])
        XCTAssertEqual(UnitEditing.paste(copied, into: &frame), [3,4])
        XCTAssertEqual(frame.units[3].name, "arm#1"); XCTAssertEqual(frame.units[4].joints[0].attributes["attached"], "arm#1&1")
        try FrameManipulation.move(&frame, unitIndex: 3, jointID: 0, x: 50, y: 60)
        XCTAssertEqual(frame.units[4].joints[0].x, 150); XCTAssertEqual(frame.units[1].joints[0].x, 100)
        XCTAssertEqual(copied[1].joints[0].attributes["attached"], "arm&1")
    }
    func testDeleteSlaveRetainsMasterAndDeleteMasterRemovesDescendants() {
        var frame = fixture(); UnitEditing.remove(1, from: &frame)
        XCTAssertEqual(frame.units.map(\.name), ["arm", "other"])
        frame = fixture(); UnitEditing.remove(0, from: &frame)
        XCTAssertEqual(frame.units.map(\.name), ["other"])
    }
    func testDetachShiftsAndReorderingPreservesAttachmentNames() {
        var frame = fixture()
        XCTAssertTrue(UnitEditing.detach(1, in: &frame)); XCTAssertNil(frame.units[1].joints[0].attributes["attached"])
        XCTAssertEqual(frame.units[1].joints[0].x, 125); XCTAssertEqual(frame.units[1].joints[0].y, 25)
        XCTAssertFalse(UnitEditing.detach(1, in: &frame))
        XCTAssertTrue(UnitEditing.rearrange(0, forward: true, in: &frame))
        XCTAssertEqual(UnitEditing.orderedIndices(in: frame), [1,0,2])
        XCTAssertFalse(UnitEditing.rearrange(2, forward: true, in: &frame))
    }
}
