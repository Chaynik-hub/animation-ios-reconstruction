import XCTest
@testable import AnimationCore
final class SceneRoundTripTests:XCTestCase {
    func testOriginalGeometryAndAttributesSurviveRoundTrip()throws {
        let url=try XCTUnwrap(Bundle.module.url(forResource:"engine",withExtension:"xml",subdirectory:"Fixtures"))
        var original=try SceneXMLReader.read(Data(contentsOf:url))
        original.frames[0].units[0].joints[0].x+=17
        original.frames[0].units[0].joints[0].attributes["attached"]="person#1&7"
        let loaded=try SceneXMLReader.read(SceneXMLWriter.write(original))
        XCTAssertEqual(loaded.width,original.width);XCTAssertEqual(loaded.frames.count,original.frames.count)
        for (left,right) in zip(original.frames,loaded.frames){for (a,b) in zip(left.units,right.units){XCTAssertEqual(a.name,b.name);XCTAssertEqual(a.joints.map(\.x),b.joints.map(\.x));XCTAssertEqual(a.joints.map(\.y),b.joints.map(\.y));XCTAssertEqual(a.joints.map(\.parent),b.joints.map(\.parent));XCTAssertEqual(a.attributes,b.attributes)}}
        XCTAssertEqual(loaded.frames[0].units[0].joints[0].attributes["attached"],"person#1&7")
    }
}
