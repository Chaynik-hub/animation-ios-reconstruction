import XCTest
@testable import AnimationCore

final class MotionRetargetTests: XCTestCase {
    func testTransfersMotionAcrossDifferentIDsAndProportions() throws {
        let root = Joint(id: 1, x: 0, y: 0, parent: nil, attributes: [:])
        let tip = Joint(id: 2, x: 10, y: 0, parent: 1, attributes: ["name": "arm"])
        let source = SceneUnit(name: "first", joints: [root, tip], attributes: [:])
        let target = SceneUnit(name: "second", joints: [
            Joint(id: 100, x: 50, y: 60, parent: nil, attributes: [:]),
            Joint(id: 200, x: 50, y: 80, parent: 100, attributes: ["name": "arm"])
        ], attributes: ["scale": "2"])
        var sample = source
        sample.joints[0].x = 5
        sample.joints[1].x = 5
        sample.joints[1].y = 10
        let retarget = try XCTUnwrap(MotionRetarget(source: source, target: target))
        let start = try retarget.pose(source)
        XCTAssertEqual(start.joints[0].x, 50, accuracy: 0.001)
        XCTAssertEqual(start.joints[0].y, 60, accuracy: 0.001)
        XCTAssertEqual(start.joints[1].x, 70, accuracy: 0.001)
        XCTAssertEqual(start.joints[1].y, 60, accuracy: 0.001)
        let output = try retarget.pose(sample)
        XCTAssertEqual(output.name, target.name)
        XCTAssertEqual(output.joints[0].x, 60, accuracy: 0.001)
        XCTAssertEqual(output.joints[1].x, 60, accuracy: 0.001)
        XCTAssertEqual(output.joints[1].y, 80, accuracy: 0.001)
        XCTAssertEqual(output.attributes, target.attributes)
    }
}
