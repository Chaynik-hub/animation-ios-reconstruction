import Foundation

public enum SpriteTransform {
    public enum Operation { case move(dx: Double, dy: Double), rotate(radians: Double), scale(factor: Double) }
    /// Apply to a gesture-start snapshot so repeated callbacks cannot accumulate rounding or scale.
    public static func apply(_ operation: Operation, to frame: inout SceneFrame, unitIndex: Int) throws {
        guard frame.units.indices.contains(unitIndex), let base = frame.units[unitIndex].joints.first(where: { $0.attributes["base"] == "true" }) else { throw PoseError.incompatibleTopology }
        let affected = UnitEditing.descendants(in: frame, of: unitIndex)
        let factor: Double, angle: Double, dx: Double, dy: Double
        switch operation {
        case .move(let x, let y): factor = 1; angle = 0; dx = x; dy = y
        case .rotate(let radians): factor = 1; angle = radians; dx = 0; dy = 0
        case .scale(let value): factor = value; angle = 0; dx = 0; dy = 0
        }
        guard factor.isFinite, factor > 0, angle.isFinite, dx.isFinite, dy.isFinite else { throw PoseError.incompatibleTopology }
        let cosine = cos(angle), sine = sin(angle)
        var result = frame
        for i in affected {
            if case .scale = operation {
                let scale = (Double(frame.units[i].attributes["scale"] ?? "1") ?? 1) * factor
                guard scale.isFinite, scale > 0 else { throw PoseError.incompatibleTopology }
                result.units[i].attributes["scale"] = String(scale)
            }
            for j in frame.units[i].joints.indices {
                let x = (frame.units[i].joints[j].x - base.x) * factor
                let y = (frame.units[i].joints[j].y - base.y) * factor
                let nextX = base.x + x * cosine - y * sine + dx
                let nextY = base.y + x * sine + y * cosine + dy
                guard nextX.isFinite, nextY.isFinite else { throw PoseError.incompatibleTopology }
                result.units[i].joints[j].x = nextX; result.units[i].joints[j].y = nextY
            }
        }
        frame = result
    }
}
