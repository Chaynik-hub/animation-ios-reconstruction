import XCTest
@testable import AnimationCore
final class UnitIdentityTests:XCTestCase {
    func testOriginalNumberingRules() {
        let unit=SceneUnit(name:"basic:person",joints:[],attributes:[:])
        var frame=SceneFrame(id:0,units:[],attributes:[:])
        XCTAssertEqual(UnitIdentity.inserting(unit.name,in:frame),unit.name)
        frame.units=[unit]
        XCTAssertEqual(UnitIdentity.inserting(unit.name,in:frame),"basic:person#1")
        frame.units.append(SceneUnit(name:"basic:person#3",joints:[],attributes:[:]))
        XCTAssertEqual(UnitIdentity.inserting(unit.name,in:frame),"basic:person#4")
        XCTAssertEqual(UnitIdentity.inserting("basic:person#2",in:frame),"basic:person#2")
    }
}
