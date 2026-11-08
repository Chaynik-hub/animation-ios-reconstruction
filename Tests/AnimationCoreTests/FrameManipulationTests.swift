import XCTest
@testable import AnimationCore
final class FrameManipulationTests:XCTestCase {
    func testLengthFactorLeavesNeighbouringJointsAndAttachmentsInPlace() {
        let joints = [
            Joint(id: 0, x: 0, y: 0, parent: nil, attributes: [:]),
            Joint(id: 1, x: 10, y: 0, parent: 0, attributes: ["attachable": "master"]),
            Joint(id: 2, x: 20, y: 0, parent: 1, attributes: [:])
        ]
        let arm = SceneUnit(name: "arm", joints: joints, attributes: [:])
        let held = SceneUnit(name: "held", joints: [
            Joint(id: 0, x: 10, y: 0, parent: nil, attributes: ["base": "true", "attachable": "slave", "attached": "arm&1"])
        ], attributes: [:])
        var frame = SceneFrame(id: 0, units: [arm, held], attributes: [:])
        XCTAssertTrue(FrameManipulation.setBoneLengthFactor(1.5, in: &frame, unitIndex: 0, jointID: 1))
        XCTAssertEqual(frame.units[0].joints.map(\.x), joints.map(\.x))
        XCTAssertEqual(frame.units[1], held)
        XCTAssertEqual(FrameManipulation.boneLengthFactor(frame.units[0].joints[1]), 1.5)
        XCTAssertEqual(FrameManipulation.boneLengthFactor(frame.units[0].joints[2]), 1)
        XCTAssertTrue(FrameManipulation.setBoneLengthFactor(1, in: &frame, unitIndex: 0, jointID: 1))
        XCTAssertEqual(frame.units[0], arm)
    }
    func testAxisResizeAndPosePasteWithoutMovingRoot() {
        let original = SceneUnit(name: "arm", joints: [
            Joint(id: 0, x: 0, y: 0, parent: nil, attributes: ["base": "true"]),
            Joint(id: 1, x: 3, y: 4, parent: 0, attributes: [:]),
            Joint(id: 2, x: 3, y: 6, parent: 1, attributes: [:])
        ], attributes: [:])
        var frame = SceneFrame(id: 0, units: [original], attributes: [:])
        XCTAssertTrue(FrameManipulation.resizeBone(in: &frame, unitIndex: 0, jointID: 1, length: 10))
        let pose = frame.units[0]
        XCTAssertEqual(pose.joints.map(\.x), [0, 6, 6])
        XCTAssertEqual(pose.joints.map(\.y), [0, 8, 10])
        frame.units[0] = original
        for index in frame.units[0].joints.indices { frame.units[0].joints[index].x += 20 }
        XCTAssertTrue(FrameManipulation.pastePose(pose, into: &frame, unitIndex: 0, includeRoot: false))
        XCTAssertEqual(frame.units[0].joints.map(\.x), [20, 26, 26])
        XCTAssertTrue(FrameManipulation.pastePose(pose, into: &frame, unitIndex: 0))
        XCTAssertEqual(frame.units[0], pose)
    }
    func testNearbySwordSnapsToVacantHand() {
        let arm=SceneUnit(name:"arm",joints:[Joint(id:7,x:100,y:100,parent:nil,attributes:["base":"true","attachable":"master"])],attributes:[:])
        let sword=SceneUnit(name:"sword",joints:[Joint(id:0,x:110,y:100,parent:nil,attributes:["base":"true","attachable":"slave"]),Joint(id:1,x:160,y:100,parent:0,attributes:[:])],attributes:[:])
        var frame=SceneFrame(id:0,units:[arm,sword],attributes:[:])
        XCTAssertEqual(FrameManipulation.attachmentHint(in: frame, unitIndex: 1, radius: 25)?.point.id, 7)
        XCTAssertNil(FrameManipulation.attachmentHint(in: frame, unitIndex: 1, radius: 5))
        XCTAssertTrue(FrameManipulation.attachNearby(&frame,unitIndex:1,radius:25))
        XCTAssertNil(FrameManipulation.attachmentHint(in: frame, unitIndex: 1, radius: 25))
        XCTAssertEqual(frame.units[1].joints[0].x,100)
        XCTAssertEqual(frame.units[1].joints[1].x,150)
        XCTAssertEqual(frame.units[1].joints[0].attributes["attached"],"arm&7")
        XCTAssertFalse(FrameManipulation.attachNearby(&frame,unitIndex:1,radius:25))
    }
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
