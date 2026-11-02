import XCTest
import ZIPFoundation
@testable import AnimationIOS
final class UserSpriteLibraryTests: XCTestCase {
    func testATIImportPersistsUniqueItemsAndRewritesPortableArchive() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("ati-test-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)}
        let source=try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("Content/Reference/practice.ats"))
        let archive=try Archive(url:source,accessMode:.read),entry=try XCTUnwrap(archive.first(where:{$0.path.lowercased().hasSuffix(".ati")}))
        var bytes=Data();_ = try archive.extract(entry){bytes.append($0)}
        let input=folder.appendingPathComponent("My sprite.ati");try bytes.write(to:input)
        let first=try UserSpriteLibrary.importATI(input,directory:folder)
        let second=try UserSpriteLibrary.importATI(input,directory:folder)
        XCTAssertNotEqual(first.name,second.name);XCTAssertEqual(first.packID,"@user");XCTAssertFalse(first.parts.isEmpty)
        let records=UserSpriteLibrary.records(in:folder);XCTAssertEqual(records.count,2);XCTAssertEqual(records.first?.definition.name,first.name)
        for part in first.parts {let path=try XCTUnwrap(part["image"]);XCTAssertTrue(FileManager.default.fileExists(atPath:folder.appendingPathComponent(String(path.dropFirst(7))).path))}
        let rewritten=try Archive(url:folder.appendingPathComponent(records[0].archive),accessMode:.read)
        func read(_ name:String)throws->Data {var data=Data();_ = try rewritten.extract(try XCTUnwrap(rewritten[name])){data.append($0)};return data}
        XCTAssertEqual(try ArtworkXMLReader.read(model:read("model.xml"),assets:read("assets.xml")).name,first.name)
        XCTAssertEqual(try JSONDecoder().decode([String:String].self,from:read("native-item.json"))["title"],"My sprite")
        let invalid=folder.appendingPathComponent("invalid.ati");try Data("invalid".utf8).write(to:invalid)
        XCTAssertThrowsError(try UserSpriteLibrary.importATI(invalid,directory:folder));XCTAssertEqual(UserSpriteLibrary.records(in:folder).count,2)
    }
}
