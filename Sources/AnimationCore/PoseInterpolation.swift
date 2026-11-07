import Foundation

public enum PoseError: Error { case incompatibleTopology, cyclicSkeleton, invalidScale }

/// Port of NlerpInterpolator.inbetweenStatesAt for unattached skeletal poses.
/// FrameInterpolation reconciles attachments and interpolates the camera.
public enum PoseInterpolation {
    public static func between(_ first: SceneUnit, _ second: SceneUnit, progress: Double) throws -> SceneUnit {
        let t = min(1, max(0, progress))
        guard first.joints.count == second.joints.count, Set(first.joints.map(\.id)).count == first.joints.count,
              Set(second.joints.map(\.id)).count == second.joints.count else { throw PoseError.incompatibleTopology }
        let a = Dictionary(uniqueKeysWithValues: first.joints.map { ($0.id, $0) })
        let b = Dictionary(uniqueKeysWithValues: second.joints.map { ($0.id, $0) })
        guard Set(a.keys) == Set(b.keys), first.joints.allSatisfy({ b[$0.id]?.parent == $0.parent }) else { throw PoseError.incompatibleTopology }
        let sa = Double(first.attributes["scale"] ?? "1") ?? 1
        let sb = Double(second.attributes["scale"] ?? "1") ?? 1
        guard sa.isFinite, sb.isFinite, sa > 0.0001, sb > 0.0001 else { throw PoseError.invalidScale }
        let scale = sa + (sb - sa) * t
        var computed: [Int:Joint] = [:]
        var visiting = Set<Int>()
        func joint(_ id: Int) throws -> Joint {
            if let value = computed[id] { return value }
            guard visiting.insert(id).inserted else { throw PoseError.cyclicSkeleton }
            guard let x = a[id], let y = b[id] else { throw PoseError.incompatibleTopology }
            var value = x
            if y.attributes["nativeAxisStretch"] == "true" { value.attributes["nativeAxisStretch"] = "true" }
            if let parentID = x.parent {
                guard let ap = a[parentID], let bp = b[parentID] else { throw PoseError.incompatibleTopology }
                let parent = try joint(parentID)
                let ax = x.x-ap.x, ay = x.y-ap.y, bx = y.x-bp.x, by = y.y-bp.y
                let la = hypot(ax, ay), lb = hypot(bx, by)
                let length = (la/sa + (lb/sb-la/sa)*t)*scale
                let angle: Double
                if la <= 0.0001 { angle = atan2(by,bx) }
                else if lb <= 0.0001 { angle = atan2(ay,ax) }
                else {
                    let start = atan2(ay,ax)
                    let delta = atan2(sin(atan2(by,bx)-start), cos(atan2(by,bx)-start))
                    angle = start + delta*t
                }
                value.x = parent.x + cos(angle)*length
                value.y = parent.y + sin(angle)*length
            } else {
                value.x = x.x + (y.x-x.x)*t
                value.y = x.y + (y.y-x.y)*t
            }
            visiting.remove(id); computed[id] = value; return value
        }
        var output = first
        output.joints = try first.joints.map { try joint($0.id) }
        output.attributes["scale"] = String(scale)
        let alphaA = Double(first.attributes["alpha"] ?? "1") ?? 1
        let alphaB = Double(second.attributes["alpha"] ?? "1") ?? 1
        output.attributes["alpha"] = String(min(1,max(0,alphaA+(alphaB-alphaA)*t)))
        output.attributes["flipped"] = (t < 0.5 ? first : second).attributes["flipped"]
        return output
    }
}
