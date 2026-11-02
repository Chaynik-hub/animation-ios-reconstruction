import XCTest
@testable import AnimationCore

final class ArtworkXMLReaderTests:XCTestCase {
    func testReadsActualEmbeddedItemGeometryAndOffsets()throws {
        let folder=Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let item=try ArtworkXMLReader.read(model:Data(contentsOf:folder.appendingPathComponent("custom-item-model.xml")),assets:Data(contentsOf:folder.appendingPathComponent("custom-item-assets.xml")))
        XCTAssertEqual(item.name,"@:ch3")
        XCTAssertEqual(item.points.count,4);XCTAssertEqual(item.parts.count,3)
        XCTAssertEqual(item.points[2]["y"],"-249")
        XCTAssertEqual(item.parts[0]["bm"],"bm_1.png")
        XCTAssertEqual(item.parts[0]["x_offset"],"-69")
    }
    func testRejectsAssetReferencingMissingBone() {
        XCTAssertThrowsError(try ArtworkXMLReader.read(model:Data("<unit name='a'><point id='0' x='0' y='0' base='true'/></unit>".utf8),assets:Data("<unit name='a'><edgeAsset start='0' end='1' bm='part.png'/></unit>".utf8)))
    }
    func testRejectsNonFiniteGeometry() {
        XCTAssertThrowsError(try ArtworkXMLReader.read(model:Data("<unit><point id='0' x='nan' y='0'/></unit>".utf8),assets:Data("<unit><edgeAsset start='0' end='0'/></unit>".utf8)))
    }
}
