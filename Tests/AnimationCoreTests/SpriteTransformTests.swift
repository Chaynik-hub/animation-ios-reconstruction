import XCTest
@testable import AnimationCore
final class SpriteTransformTests: XCTestCase {
    private func fixture() -> SceneFrame {
        SceneFrame(id: 0, units: [
            SceneUnit(name: "arm", joints: [Joint(id: 0, x: 10, y: 20, parent: nil, attributes: ["base":"true"]), Joint(id: 1, x: 110, y: 20, parent: 0, attributes: [:])], attributes: ["scale":"0.5"]),
            SceneUnit(name: "sword", joints: [Joint(id: 0, x: 110, y: 20, parent: nil, attributes: ["base":"true","attachable":"slave","attached":"arm&1"]), Joint(id: 1, x: 160, y: 20, parent: 0, attributes: [:])], attributes: ["scale":"2"]),
            SceneUnit(name: "other", joints: [], attributes: [:])], attributes: [:])
    }
    func testScalePreservesBaseAndAttachmentAndChangesBitmapScales() throws {
        var frame = fixture(); let other = frame.units[2]
        try SpriteTransform.apply(.scale(factor: 2), to: &frame, unitIndex: 0)
        XCTAssertEqual(frame.units[0].joints[0].x, 10); XCTAssertEqual(frame.units[0].joints[1].x, 210)
        XCTAssertEqual(frame.units[1].joints[0].x, 210); XCTAssertEqual(frame.units[1].joints[1].x, 310)
        XCTAssertEqual(Double(frame.units[0].attributes["scale"]!), 1); XCTAssertEqual(Double(frame.units[1].attributes["scale"]!), 4)
        XCTAssertEqual(frame.units[1].joints[0].attributes["attached"], "arm&1"); XCTAssertEqual(frame.units[2], other)
        try SpriteTransform.apply(.scale(factor: 0.5), to: &frame, unitIndex: 0)
        XCTAssertEqual(frame.units[0].joints, fixture().units[0].joints)
    }
    func testRotationAndMoveIncludeDescendantsWithoutChangingBoneLengths() throws {
        var frame = fixture()
        try SpriteTransform.apply(.rotate(radians: .pi / 2), to: &frame, unitIndex: 0)
        XCTAssertEqual(frame.units[0].joints[1].x, 10, accuracy: 1e-8); XCTAssertEqual(frame.units[0].joints[1].y, 120, accuracy: 1e-8)
        XCTAssertEqual(frame.units[1].joints[0].y, 120, accuracy: 1e-8); XCTAssertEqual(frame.units[1].joints[1].y, 170, accuracy: 1e-8)
        try SpriteTransform.apply(.move(dx: 5, dy: -10), to: &frame, unitIndex: 0)
        XCTAssertEqual(frame.units[0].joints[0].x, 15); XCTAssertEqual(frame.units[1].joints[0].y, 110, accuracy: 1e-8)
        XCTAssertEqual(frame.units[1].attributes["scale"], "2")
    }
    func testInvalidTransformDoesNotPartiallyMutateDocument() {
        for operation in [SpriteTransform.Operation.scale(factor: 0), .scale(factor: .infinity), .rotate(radians: .nan), .move(dx: .infinity, dy: 0)] {
            var frame = fixture(); let original = frame
            XCTAssertThrowsError(try SpriteTransform.apply(operation, to: &frame, unitIndex: 0)); XCTAssertEqual(frame, original)
        }
    }
}
