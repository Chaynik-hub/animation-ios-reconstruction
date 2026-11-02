import XCTest
@testable import AnimationCore
final class PoseTests: XCTestCase {
    private func pose(_ x: Double, _ y: Double) -> SceneUnit {
        SceneUnit(name: "bone", joints: [Joint(id: 0, x: 0, y: 0, parent: nil, attributes: ["base":"true"]), Joint(id: 1,x: x,y: y,parent: 0,attributes: [:])], attributes: ["scale":"1"])
    }
    func testRotatingBoneDoesNotCollapseAtMidpoint() throws {
        let result = try PoseInterpolation.between(pose(100,0), pose(0,100), progress: 0.5)
        XCTAssertEqual(hypot(result.joints[1].x,result.joints[1].y),100,accuracy:0.0001)
        XCTAssertEqual(result.joints[1].x,70.710678,accuracy:0.0001)
    }
    func testMismatchedTopologyIsRejected() {
        var second = pose(0,100); second.joints[1].parent = nil
        XCTAssertThrowsError(try PoseInterpolation.between(pose(100,0),second,progress:0.5))
    }
}
