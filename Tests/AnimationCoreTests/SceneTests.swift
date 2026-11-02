import XCTest
@testable import AnimationCore
final class SceneTests: XCTestCase {
    func testOriginalEmbeddedSceneGeometry() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "engine", withExtension: "xml", subdirectory: "Fixtures"))
        let document = try SceneXMLReader.read(Data(contentsOf: url))
        XCTAssertEqual(document.width, 480)
        XCTAssertEqual(document.height, 640)
        XCTAssertEqual(document.interframes, 4)
        XCTAssertEqual(document.frames.first?.units.first?.joints.first?.x, 234)
        XCTAssertEqual(document.frames.first?.units.first?.joints.first?.y, 442)
        XCTAssertEqual(document.frames.first?.units.first?.name, "@:ch3")
    }
    func testInvalidCoordinatesAreRejected() {
        let xml = "<scene w=\"480\" h=\"640\"><frame id=\"1\"><unit name=\"test\"><point id=\"1\" x=\"nan\" y=\"0\"/></unit></frame></scene>"
        XCTAssertThrowsError(try SceneXMLReader.read(Data(xml.utf8)))
    }
}
