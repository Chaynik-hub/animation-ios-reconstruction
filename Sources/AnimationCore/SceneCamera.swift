import Foundation

public struct SceneCamera: Equatable, Sendable {
    public var x: Double = 0
    public var y: Double = 0
    public var zoom: Double = 1

    public init() {}

    public init(frame: SceneFrame) {
        func number(_ key: String, fallback: Double) -> Double {
            guard let value = Double(frame.attributes[key] ?? ""), value.isFinite else { return fallback }
            return value
        }
        x = number("nativeCameraX", fallback: 0)
        y = number("nativeCameraY", fallback: 0)
        zoom = min(8, max(0.25, number("nativeCameraZoom", fallback: 1)))
    }

    public func write(to frame: inout SceneFrame) {
        frame.attributes["nativeCameraX"] = x == 0 ? nil : String(x)
        frame.attributes["nativeCameraY"] = y == 0 ? nil : String(y)
        frame.attributes["nativeCameraZoom"] = zoom == 1 ? nil : String(zoom)
    }

    public func interpolated(to end: SceneCamera, progress: Double) -> SceneCamera {
        var camera = self
        camera.x += (end.x - x) * progress
        camera.y += (end.y - y) * progress
        camera.zoom += (end.zoom - zoom) * progress
        return camera
    }
}
