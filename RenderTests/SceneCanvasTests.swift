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
