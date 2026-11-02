import XCTest
@testable import AnimationCore
final class FrameManipulationTests:XCTestCase {
    func testAttachedSwordRotatesWithHand()throws {
        let arm=SceneUnit(name:"arm",joints:[Joint(id:0,x:0,y:0,parent:nil,attributes:["base":"true"]),Joint(id:1,x:100,y:0,parent:0,attributes:["attachable":"master"])],attributes:[:])
        let sword=SceneUnit(name:"sword",joints:[Joint(id:0,x:100,y:0,parent:nil,attributes:["base":"true","attachable":"slave","attached":"arm&1"]),Joint(id:1,x:150,y:0,parent:0,attributes:[:])],attributes:[:])
        var frame=SceneFrame(id:0,units:[arm,sword],attributes:[:])
        try FrameManipulation.move(&frame,unitIndex:0,jointID:1,x:100,y:100)
        XCTAssertEqual(frame.units[1].joints[0].x,frame.units[0].joints[1].x,accuracy:0.0001)
        XCTAssertEqual(frame.units[1].joints[0].y,frame.units[0].joints[1].y,accuracy:0.0001)
        XCTAssertEqual(hypot(frame.units[1].joints[1].x-frame.units[1].joints[0].x,frame.units[1].joints[1].y-frame.units[1].joints[0].y),50,accuracy:0.0001)
        let prior=frame
        try FrameManipulation.move(&frame,unitIndex:1,jointID:0,x:999,y:999)
        XCTAssertEqual(frame,prior,"Attached slave's base cannot be dragged away from its master")
    }
}
