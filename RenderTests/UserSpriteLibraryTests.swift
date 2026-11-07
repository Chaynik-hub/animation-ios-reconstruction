import XCTest
import ZIPFoundation
@testable import AnimationIOS
final class UserSpriteLibraryTests: XCTestCase {
    func testPackKeepsItsCoverAndTitleWhenOneSpriteHasMissingResources() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let reference = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("Content/Reference/practice.ats"))
        let original = try Archive(url: reference, accessMode: .read)
        let sprite = try XCTUnwrap(original.first { $0.path.lowercased().hasSuffix(".ati") })
        var data = Data()
        _ = try original.extract(sprite) { data.append($0) }

        let missing = folder.appendingPathComponent("missing.ati")
        let incomplete = try Archive(url: missing, accessMode: .create)
        func add(_ path: String, _ data: Data, to archive: Archive) throws {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) {
                offset, count in data.subdata(in: Int(offset)..<(Int(offset) + count))
            }
        }
        try add("notes.txt", Data("Missing resources".utf8), to: incomplete)

        let source = folder.appendingPathComponent("filename.atp")
        let pack = try Archive(url: source, accessMode: .create)
        try add("items/Sprite.ati", data, to: pack)
        try add("items/Missing.ati", Data(contentsOf: missing), to: pack)
        try add("meta.txt", try JSONEncoder().encode(["mHumanName": "Pack Title"]), to: pack)
        let png = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("Content/Icons/side_camera.png"))
        try add("logo.png", Data(contentsOf: png), to: pack)

        XCTAssertEqual(try UserSpriteLibrary.importFile(source, directory: folder), 1)
        let definitions = UserSpriteLibrary.definitions(in: folder)
        XCTAssertEqual(definitions.count, 1)
        let item = try XCTUnwrap(definitions.first)
        XCTAssertTrue(item.packID?.hasSuffix(":Pack Title") == true)
        let cover = try XCTUnwrap(item.packCover)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(String(cover.dropFirst(7)))), try Data(contentsOf: png))
    }

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
