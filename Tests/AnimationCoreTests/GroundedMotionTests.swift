import XCTest
@testable import AnimationCore

final class GroundedMotionTests: XCTestCase {
    func testWalkKeepsPlantedFootAndBoneLengths() throws {
        let unit = SceneUnit(name: "walker", joints: [
            Joint(id: 0, x: 0, y: 0, parent: nil, attributes: ["base": "true"]),
            Joint(id: 1, x: 0, y: -60, parent: 0, attributes: [:]),
            Joint(id: 2, x: -18, y: 42, parent: 0, attributes: [:]),
            Joint(id: 3, x: -18, y: 90, parent: 2, attributes: [:]),
            Joint(id: 4, x: 18, y: 42, parent: 0, attributes: [:]),
            Joint(id: 5, x: 18, y: 90, parent: 4, attributes: [:])
        ], attributes: [:])
        let rig = try XCTUnwrap(GroundedMotion(unit: unit))
        let pose = rig.pose(.walk, progress: 0.125, direction: 1)
        XCTAssertEqual(pose.joints[5].x, unit.joints[5].x, accuracy: 0.001)
        XCTAssertEqual(pose.joints[5].y, unit.joints[5].y, accuracy: 0.001)
        XCTAssertLessThan(pose.joints[3].y, unit.joints[3].y)
        for index in [2, 3, 4, 5] {
            let parent = try XCTUnwrap(unit.joints[index].parent)
            let before = hypot(unit.joints[index].x - unit.joints[parent].x, unit.joints[index].y - unit.joints[parent].y)
            let after = hypot(pose.joints[index].x - pose.joints[parent].x, pose.joints[index].y - pose.joints[parent].y)
            XCTAssertEqual(before, after, accuracy: 0.001)
        }
        XCTAssertLessThan(rig.pose(.jump, progress: 0.5, direction: 1).joints[0].y, 0)
        XCTAssertEqual(rig.pose(.jump, progress: 1, direction: 1).joints[5].y, 90, accuracy: 0.001)
    }
}
