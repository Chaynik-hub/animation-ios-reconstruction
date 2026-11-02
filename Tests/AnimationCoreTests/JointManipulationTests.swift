import XCTest
@testable import AnimationCore
final class JointManipulationTests:XCTestCase {
    func testDragRotatesWholeBranchWithoutSeparatingParts() throws {
        var unit=SceneUnit(name:"arm",joints:[Joint(id:0,x:0,y:0,parent:nil,attributes:["base":"true"]),Joint(id:1,x:100,y:0,parent:0,attributes:[:]),Joint(id:2,x:200,y:0,parent:1,attributes:[:])],attributes:[:])
        try JointManipulation.move(&unit,jointID:1,x:1000,y:1000)
        XCTAssertEqual(hypot(unit.joints[1].x,unit.joints[1].y),100,accuracy:0.00001)
        XCTAssertEqual(hypot(unit.joints[2].x-unit.joints[1].x,unit.joints[2].y-unit.joints[1].y),100,accuracy:0.00001)
        XCTAssertEqual(unit.joints[2].x,2*unit.joints[1].x,accuracy:0.00001)
    }
    func testDraggingBaseTranslatesAllJoints() throws {
        var unit=SceneUnit(name:"body",joints:[Joint(id:0,x:0,y:0,parent:nil,attributes:["base":"true"]),Joint(id:1,x:100,y:0,parent:0,attributes:[:])],attributes:[:])
        try JointManipulation.move(&unit,jointID:0,x:5,y:9)
        XCTAssertEqual(unit.joints[1].x,105);XCTAssertEqual(unit.joints[1].y,9)
    }
}
