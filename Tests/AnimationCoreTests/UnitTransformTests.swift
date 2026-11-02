import XCTest
@testable import AnimationCore
final class UnitTransformTests:XCTestCase {
    func testFlipIncludesAttachedSwordAndLeavesOtherUnitsAlone()throws {
        let arm=SceneUnit(name:"arm",joints:[Joint(id:0,x:50,y:0,parent:nil,attributes:["base":"true"]),Joint(id:1,x:150,y:0,parent:0,attributes:["attachable":"master"])],attributes:[:])
        let sword=SceneUnit(name:"sword",joints:[Joint(id:0,x:150,y:0,parent:nil,attributes:["base":"true","attachable":"slave","attached":"arm&1"]),Joint(id:1,x:200,y:0,parent:0,attributes:[:])],attributes:[:])
        let other=SceneUnit(name:"other",joints:[Joint(id:0,x:500,y:0,parent:nil,attributes:["base":"true"])],attributes:[:])
        var frame=SceneFrame(id:0,units:[arm,sword,other],attributes:[:])
        try UnitTransform.flip(&frame,unitIndex:0)
        XCTAssertEqual(frame.units[0].joints[0].x,50)
        XCTAssertEqual(frame.units[0].joints[1].x,-50)
        XCTAssertEqual(frame.units[1].joints[0].x,-50)
        XCTAssertEqual(frame.units[1].joints[1].x,-100)
        XCTAssertEqual(frame.units[0].attributes["flipped"],"true")
        XCTAssertEqual(frame.units[1].attributes["flipped"],"true")
        XCTAssertEqual(frame.units[2],other)
        try UnitTransform.flip(&frame,unitIndex:0)
        XCTAssertEqual(frame.units[0].joints,arm.joints)
        XCTAssertEqual(frame.units[1].joints,sword.joints)
    }
}
