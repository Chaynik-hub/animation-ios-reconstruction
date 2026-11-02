import XCTest
@testable import AnimationCore

final class FrameInterpolationTests:XCTestCase {
    func fixture()->(SceneFrame,SceneFrame) {
        let arm=SceneUnit(name:"arm",joints:[Joint(id:0,x:0,y:0,parent:nil,attributes:["base":"true"]),Joint(id:1,x:100,y:0,parent:0,attributes:["attachable":"master"])],attributes:[:])
        let sword=SceneUnit(name:"sword",joints:[Joint(id:0,x:100,y:0,parent:nil,attributes:["base":"true","attachable":"slave","attached":"arm&1"]),Joint(id:1,x:150,y:0,parent:0,attributes:[:])],attributes:[:])
        var first=SceneFrame(id:0,units:[sword,arm],attributes:[:]),second=SceneFrame(id:1,units:[sword,arm],attributes:[:])
        second.units[1].joints[1].x=0;second.units[1].joints[1].y=100
        second.units[0].joints[0].x=0;second.units[0].joints[0].y=100
        second.units[0].joints[1].x=50;second.units[0].joints[1].y=100
        first.id=0
        return (first,second)
    }
    func testHeldObjectStaysOnHandThroughoutCurvedMotion()throws {
        let (first,second)=fixture()
        for t in stride(from:0.05,to:1.0,by:0.05) {
            let pose=try FrameInterpolation.between(first,second,progress:t)
            let sword=pose.units[0],arm=pose.units[1]
            XCTAssertEqual(sword.joints[0].x,arm.joints[1].x,accuracy:0.000001)
            XCTAssertEqual(sword.joints[0].y,arm.joints[1].y,accuracy:0.000001)
            XCTAssertEqual(hypot(arm.joints[1].x,arm.joints[1].y),100,accuracy:0.000001)
            XCTAssertEqual(sword.joints[1].x-sword.joints[0].x,50,accuracy:0.000001)
        }
    }
    func testChangedAttachmentIsDetachedInInbetween()throws {
        let (first,end)=fixture();var second=end
        second.units[0].joints[0].attributes["attached"]="null&-1"
        let pose=try FrameInterpolation.between(first,second,progress:0.5)
        XCTAssertNil(FrameManipulation.attachment(pose.units[0]))
        XCTAssertEqual(pose.units[0].joints[0].x,50,accuracy:0.0001)
        XCTAssertEqual(pose.units[0].joints[0].y,50,accuracy:0.0001)
    }
    func testAbsentMasterExcludesItsSlavesInInbetween()throws {
        let (first,end)=fixture();var second=end;second.units.removeLast()
        XCTAssertTrue(try FrameInterpolation.between(first,second,progress:0.5).units.isEmpty)
        XCTAssertEqual(try FrameInterpolation.between(first,second,progress:0),first)
        XCTAssertEqual(try FrameInterpolation.between(first,second,progress:1),second)
    }
    func testAttachmentCycleIsReportedInsteadOfRecursingForever()throws {
        let (start,end)=fixture();var first=start,second=end
        for frame in 0...1 {
            if frame==0 {first.units[1].joints[0].attributes.merge(["attachable":"slave","attached":"sword&0"]){_,new in new}}
            else {second.units[1].joints[0].attributes.merge(["attachable":"slave","attached":"sword&0"]){_,new in new}}
        }
        XCTAssertThrowsError(try FrameInterpolation.between(first,second,progress:0.5))
    }
}
