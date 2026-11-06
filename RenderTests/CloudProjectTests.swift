import XCTest
import UIKit
import ZIPFoundation
@testable import AnimationIOS

final class CloudProjectTests: XCTestCase {
    func testPortableProjectIncludesCustomArtBackgroundAndAudio() throws {
        let workspace = Workspace(); workspace.autosaveEnabled = false
        let id = UUID().uuidString
        let imageName = id + ".png", audioName = id + ".wav"
        let imageURL = workspace.directory.appendingPathComponent(imageName), audioURL = workspace.directory.appendingPathComponent(audioName)
        try Data([1,2,3]).write(to:imageURL); try Data([4,5,6]).write(to:audioURL)
        defer { try? FileManager.default.removeItem(at:imageURL); try? FileManager.default.removeItem(at:audioURL) }
        workspace.catalog = [ArtworkDefinition(name:"custom:test",points:[],parts:[["image":"@local/"+imageName]],thumbnail:"@local/"+imageName)]
        workspace.document = SceneDocument(width:100,height:100,interframes:4,frames:[SceneFrame(id:0,units:[SceneUnit(name:"custom:test",joints:[],attributes:[:])],attributes:["nativeBackgroundImage":"@local/"+imageName])],attributes:["nativeAudio":audioName])
        let archive = try CloudProjectArchive.pack(workspace)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:archive); try? FileManager.default.removeItem(at:destination) }
        let decoded = try CloudProjectArchive.unpack(archive,into:destination)
        XCTAssertEqual(decoded.frames[0].units[0].name,"custom:test")
        let sound = try XCTUnwrap(decoded.attributes["nativeAudio"])
        XCTAssertFalse(sound.contains("/")); XCTAssertEqual(try Data(contentsOf:destination.appendingPathComponent(sound)),Data([4,5,6]))
        let background = try XCTUnwrap(decoded.frames[0].attributes["nativeBackgroundImage"])
        XCTAssertTrue(background.hasPrefix("@local/"))
        XCTAssertEqual(try Data(contentsOf:destination.appendingPathComponent(String(background.dropFirst(7)))),Data([1,2,3]))
        XCTAssertNotNil(decoded.attributes["nativeArtworkDirectory"])
    }
    func testRejectsArchiveTraversal() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".animationproject")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:url); try? FileManager.default.removeItem(at:directory) }
        let archive = try Archive(url:url,accessMode:.create)
        let data = Data("{}".utf8)
        for name in ["project.json","assets/../../escape"] {
            try archive.addEntry(with:name,type:.file,uncompressedSize:Int64(data.count)) { offset,count in data.subdata(in:Int(offset)..<Int(offset)+count) }
        }
        XCTAssertThrowsError(try CloudProjectArchive.unpack(url,into:directory))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:directory.path).isEmpty)
    }
    func testExportSamplingHoldsLastPoseInsteadOfReturningToFirst() throws {
        let editor = EditorController(); editor.workspace.autosaveEnabled = false
        let a = SceneUnit(name:"test",joints:[Joint(id:0,x:10,y:10,parent:nil,attributes:["base":"true"])],attributes:[:])
        var b = a; b.joints[0].x = 90
        editor.workspace.document = SceneDocument(width:100,height:100,interframes:9,frames:[SceneFrame(id:0,units:[a],attributes:[:]),SceneFrame(id:1,units:[b],attributes:[:])],attributes:[:])
        XCTAssertEqual(editor.frameAt(0).units[0].joints[0].x,10)
        for tick in 10...30 { XCTAssertEqual(editor.frameAt(Double(tick)/60).units[0].joints[0].x,90,accuracy:0.001) }
    }
}
