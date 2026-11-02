import XCTest
import UIKit
@testable import AnimationIOS

final class SceneCanvasTests: XCTestCase {
    func testPreviousFrameRemainsTranslucentThroughBitmapRendering() throws {
        let workspace = Workspace()
        let filename = "render-test-" + UUID().uuidString + ".png"
        let url = workspace.directory.appendingPathComponent(filename)
        defer { try? FileManager.default.removeItem(at: url) }
        let tile = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { c in UIColor.black.setFill(); c.fill(CGRect(x: 0, y: 0, width: 10, height: 10)) }
        try XCTUnwrap(tile.pngData()).write(to: url)
        workspace.catalog = [ArtworkDefinition(name: "test:tile", points: [], parts: [["start":"0", "end":"1", "image":"@local/" + filename]], thumbnail: nil)]
        let first = SceneUnit(name: "test:tile", joints: [Joint(id: 0, x: 20, y: 20, parent: nil, attributes: [:]), Joint(id: 1, x: 30, y: 20, parent: 0, attributes: [:])], attributes: ["alpha":"1"])
        var second = first
        for i in second.joints.indices { second.joints[i].x += 60 }
        workspace.document = SceneDocument(width: 100, height: 100, interframes: 4, frames: [SceneFrame(id: 0, units: [first], attributes: [:]), SceneFrame(id: 1, units: [second], attributes: [:])], attributes: [:])
        workspace.index = 1; workspace.selected = nil
        let canvas = SceneCanvas(workspace); canvas.frame = CGRect(x: 0, y: 0, width: 124, height: 124)
        let image = UIGraphicsImageRenderer(size: canvas.bounds.size).image { _ in canvas.draw(canvas.bounds) }
        let pixel = try rgba(image, x: 37, y: 37)
        XCTAssertGreaterThan(pixel[0], 190, "Previous frame must be a faint ghost, not an opaque black bitmap")
        XCTAssertLessThan(pixel[0], 230, "The ghost must remain visible")
        XCTAssertLessThanOrEqual(abs(pixel[0] - pixel[1]), 2)
    }
    func testSelectedSkeletonDrawsConnectingBonesAndExportOmitsThem() throws {
        let workspace = Workspace()
        let unit = SceneUnit(name: "test:empty", joints: [Joint(id: 0, x: 20, y: 50, parent: nil, attributes: ["base":"true"]), Joint(id: 1, x: 80, y: 50, parent: 0, attributes: [:])], attributes: [:])
        workspace.catalog = [ArtworkDefinition(name: "test:empty", points: [], parts: [], thumbnail: nil)]
        workspace.document = SceneDocument(width: 100, height: 100, interframes: 4, frames: [SceneFrame(id: 0, units: [unit], attributes: [:])], attributes: [:]); workspace.selected = 0
        let canvas = SceneCanvas(workspace); canvas.frame = CGRect(x: 0, y: 0, width: 124, height: 124)
        let image = UIGraphicsImageRenderer(size: canvas.bounds.size).image { _ in canvas.draw(canvas.bounds) }
        let selected = try rgba(image, x: 62, y: 62)
        XCTAssertGreaterThan(selected[0] - selected[2], 80, "Bone midpoint must contain the orange connecting line")
        let exported = try rgba(canvas.snapshot(size: CGSize(width: 100, height: 100)), x: 50, y: 50)
        XCTAssertGreaterThan(exported[0], 250); XCTAssertGreaterThan(exported[2], 250)
    }
    func testBaseTapShowsThreeOriginalHandlesWithConstantHitSize() throws {
        let workspace = Workspace()
        let unit = SceneUnit(name: "test:unit", joints: [Joint(id: 0, x: 50, y: 50, parent: nil, attributes: ["base":"true"]), Joint(id: 1, x: 70, y: 50, parent: 0, attributes: [:])], attributes: [:])
        workspace.catalog = [ArtworkDefinition(name: "test:unit", points: [], parts: [], thumbnail: nil)]
        workspace.document = SceneDocument(width: 100, height: 100, interframes: 4, frames: [SceneFrame(id: 0, units: [unit], attributes: [:])], attributes: [:]); workspace.selected = nil
        let canvas = SceneCanvas(workspace); canvas.frame = CGRect(x: 0, y: 0, width: 500, height: 500)
        canvas.selectBase(at: CGPoint(x: 250, y: 250))
        let handles = canvas.subviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(handles.count, 3); XCTAssertTrue(handles.allSatisfy { !$0.isHidden && $0.frame.width == 65 && $0.image(for: .normal) != nil })
        canvas.cameraScale = 2; canvas.updateTransformControls()
        XCTAssertTrue(handles.allSatisfy { $0.frame.width == 65 && canvas.bounds.contains($0.frame) })
        canvas.handles = false; canvas.updateTransformControls(); XCTAssertTrue(handles.allSatisfy(\.isHidden))
    }
    func testBundledBackgroundsAndAssetAnimationReachRenderer() throws {
        let workspace=Workspace()
        XCTAssertEqual(workspace.backgroundCatalog.count,83)
        for definition in workspace.backgroundCatalog {
            XCTAssertTrue(FileManager.default.fileExists(atPath:Bundle.main.resourceURL!.appendingPathComponent("Content/"+definition.image).path))
            XCTAssertTrue(FileManager.default.fileExists(atPath:Bundle.main.resourceURL!.appendingPathComponent("Content/"+definition.thumbnail).path))
        }
        workspace.document=SceneDocument(width:320,height:240,interframes:4,frames:[SceneFrame(id:0,units:[],attributes:[:])],attributes:[:]);workspace.index=0;workspace.selected=nil
        let canvas=SceneCanvas(workspace)
        let white=canvas.snapshot(size:CGSize(width:320,height:240)).pngData()
        workspace.document.frames[0].attributes["nativeBackgroundID"]="common:bank"
        XCTAssertNotEqual(canvas.snapshot(size:CGSize(width:320,height:240)).pngData(),white)
        let item=try XCTUnwrap(workspace.catalog.first(where:{$0.name=="farid.things:semaphor"}))
        let unit=item.unit(at:CGPoint(x:160,y:120));workspace.document.frames=(0..<4).map{SceneFrame(id:$0,units:[unit],attributes:[:])}
        workspace.assetAnimations=[unit.name:AssetAnimation.Configuration(period:3,pingPong:true)]
        XCTAssertEqual(workspace.applyAssetAnimations(to:workspace.frame,tick:2).units[0].attributes["state"],"1")
        XCTAssertEqual(workspace.applyAssetAnimations(to:workspace.frame,tick:11).units[0].attributes["state"],"2")
    }
    private func rgba(_ image: UIImage, x: Int, y: Int) throws -> [Int] {
        let cg = try XCTUnwrap(image.cgImage)
        let px = Int(CGFloat(x) * image.scale), py = Int(CGFloat(y) * image.scale)
        let crop = try XCTUnwrap(cg.cropping(to: CGRect(x: px, y: py, width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return bytes.map(Int.init)
    }
}
