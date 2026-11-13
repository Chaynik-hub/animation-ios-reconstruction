import Foundation

public struct SceneCamera: Equatable, Sendable {
    public var x: Double = 0
    public var y: Double = 0
    public var zoom: Double = 1
    public var rotation: Double = 0

    public init() {}

    public init(frame: SceneFrame, background: Bool = false) {
        let prefix = background ? "nativeBackgroundMove" : "nativeCamera"
        func number(_ key: String, fallback: Double) -> Double {
            guard let value = Double(frame.attributes[key] ?? ""), value.isFinite else { return fallback }
            return value
        }
        x = number(prefix + "X", fallback: 0)
        y = number(prefix + "Y", fallback: 0)
        rotation = number(prefix + "Rotation", fallback: 0)
        zoom = min(8, max(0.2, number(prefix + "Zoom", fallback: 1)))
    }

    public func write(to frame: inout SceneFrame, background: Bool = false) {
        let prefix = background ? "nativeBackgroundMove" : "nativeCamera"
        frame.attributes[prefix + "X"] = x == 0 ? nil : String(x)
        frame.attributes[prefix + "Y"] = y == 0 ? nil : String(y)
        frame.attributes[prefix + "Rotation"] = rotation == 0 ? nil : String(rotation)
        frame.attributes[prefix + "Zoom"] = zoom == 1 ? nil : String(zoom)
    }

    public func interpolated(to end: SceneCamera, progress: Double) -> SceneCamera {
        var camera = self
        camera.x += (end.x - x) * progress
        camera.y += (end.y - y) * progress
        let angle = end.rotation - rotation
        camera.rotation += atan2(sin(angle), cos(angle)) * progress
        camera.zoom += (end.zoom - zoom) * progress
        return camera
    }
}
