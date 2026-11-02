import XCTest
@testable import AnimationCore

final class InverseKinematicsTests:XCTestCase {
    func arm()->SceneUnit {
        SceneUnit(name:"arm",joints:[
            Joint(id:0,x:0,y:0,parent:nil,attributes:["base":"true"]),
            Joint(id:1,x:100,y:0,parent:0,attributes:[:]),
            Joint(id:2,x:100,y:100,parent:1,attributes:["kinstart":"true","attachable":"master"]),
            Joint(id:3,x:120,y:100,parent:2,attributes:[:]),
            Joint(id:4,x:110,y:-20,parent:1,attributes:[:])],attributes:[:])
    }
    func assertLengths(_ before:SceneUnit,_ after:SceneUnit,file:StaticString=#filePath,line:UInt=#line) {
        for (i,joint) in before.joints.enumerated() {
            guard let parent=joint.parent,let p=before.joints.firstIndex(where:{$0.id==parent}) else{continue}
            XCTAssertEqual(hypot(joint.x-before.joints[p].x,joint.y-before.joints[p].y),hypot(after.joints[i].x-after.joints[p].x,after.joints[i].y-after.joints[p].y),accuracy:0.0001,file:file,line:line)
        }
    }
    func testEffectorBendsChainAndPreservesSideBranches()throws {
        let original=arm();var pose=original
        try JointManipulation.move(&pose,jointID:2,x:145,y:85)
        XCTAssertEqual(pose.joints[0],original.joints[0])
        XCTAssertEqual(pose.joints[2].x,145,accuracy:1)
        XCTAssertEqual(pose.joints[2].y,85,accuracy:1)
        XCTAssertNotEqual(pose.joints[1],original.joints[1],"An IK effector must bend its ancestors")
        assertLengths(original,pose)
    }
    func testUnreachableTargetDoesNotStretchSkeleton()throws {
        let original=arm();var pose=original
        let reached=try InverseKinematics.solve(&pose,jointID:2,x:10_000,y:10_000)
        XCTAssertFalse(reached)
        XCTAssertEqual(pose.joints[0],original.joints[0])
        assertLengths(original,pose)
        XCTAssertLessThanOrEqual(hypot(pose.joints[2].x,pose.joints[2].y),200.0001)
    }
    func testStopJointAnchorsOnlyItsChain()throws {
        var pose=arm();pose.joints[1].attributes["kinstop"]="true"
        let before=pose
        try JointManipulation.move(&pose,jointID:2,x:170,y:90)
        XCTAssertEqual(pose.joints[0],before.joints[0]);XCTAssertEqual(pose.joints[1],before.joints[1])
        XCTAssertEqual(pose.joints[4],before.joints[4],"Sibling branch at the chain root stays stationary")
        assertLengths(before,pose)
    }
    func testAttachedObjectFollowsItsSolvedAnchorWithoutRotating()throws {
        let sword=SceneUnit(name:"sword",joints:[Joint(id:0,x:100,y:100,parent:nil,attributes:["base":"true","attachable":"slave","attached":"arm&2"]),Joint(id:1,x:150,y:100,parent:0,attributes:[:])],attributes:[:])
        var frame=SceneFrame(id:0,units:[arm(),sword],attributes:[:])
        try FrameManipulation.move(&frame,unitIndex:0,jointID:2,x:145,y:85)
        XCTAssertEqual(frame.units[1].joints[0].x,frame.units[0].joints[2].x,accuracy:0.0001)
        XCTAssertEqual(frame.units[1].joints[0].y,frame.units[0].joints[2].y,accuracy:0.0001)
        XCTAssertEqual(frame.units[1].joints[1].x-frame.units[1].joints[0].x,50,accuracy:0.0001)
        XCTAssertEqual(frame.units[1].joints[1].y-frame.units[1].joints[0].y,0,accuracy:0.0001)
    }
    func testCollapsedBoneFailsWithoutCorruptingCoordinates()throws {
        var pose=arm();pose.joints[1].x=0
        let before=pose
        XCTAssertThrowsError(try InverseKinematics.solve(&pose,jointID:2,x:50,y:50))
        XCTAssertEqual(pose,before)
    }
    func testAngularLimitsKeepConstrainedChainCollinear()throws {
        var pose=arm()
        pose.joints[1].attributes["minRotation"]="0"
        pose.joints[1].attributes["maxRotation"]="0"
        let before=pose
        try JointManipulation.move(&pose,jointID:2,x:160,y:80)
        let a=atan2(pose.joints[1].y-pose.joints[0].y,pose.joints[1].x-pose.joints[0].x)
        let b=atan2(pose.joints[2].y-pose.joints[1].y,pose.joints[2].x-pose.joints[1].x)
        XCTAssertEqual(atan2(sin(b-a),cos(b-a)),0,accuracy:0.00011)
        assertLengths(before,pose)
    }
}
