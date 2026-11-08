import Foundation

/// Transfers changes in joint angles and root travel to a different rig.
public struct MotionRetarget {
    private let source: SceneUnit
    private let target: SceneUnit
    private let sourceRoot: Joint
    private let targetRoot: Joint
    private let mapping: [Int: Int]
    private let scale: Double

    public init?(source: SceneUnit, target: SceneUnit) {
        guard let a = source.joints.first(where: { $0.parent == nil }),
              let b = target.joints.first(where: { $0.parent == nil }) else { return nil }
        self.source = source
        self.target = target
        sourceRoot = a
        targetRoot = b
        let sourceHeight = Self.extent(source, root: a)
        let targetHeight = Self.extent(target, root: b)
        scale = targetHeight / sourceHeight
        let same = UnitIdentity.baseName(source.name) == UnitIdentity.baseName(target.name)
        var result: [Int: Int] = [:]
        for joint in target.joints where joint.parent != nil {
            let candidates = source.joints.filter { $0.parent != nil }
            if same, candidates.contains(where: { $0.id == joint.id }) {
                result[joint.id] = joint.id
            } else if let name = joint.attributes["name"], !name.isEmpty,
                      let match = candidates.first(where: { $0.attributes["name"] == name }) {
                result[joint.id] = match.id
            } else {
                let x = (joint.x - b.x) / targetHeight, y = (joint.y - b.y) / targetHeight
                let match = candidates.min {
                    hypot(($0.x - a.x) / sourceHeight - x, ($0.y - a.y) / sourceHeight - y) <
                    hypot(($1.x - a.x) / sourceHeight - x, ($1.y - a.y) / sourceHeight - y)
                }
                if let match { result[joint.id] = match.id }
            }
        }
        mapping = result
    }

    public func pose(_ sample: SceneUnit) throws -> SceneUnit {
        let moved = Dictionary(sample.joints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let targetPoints = Dictionary(target.joints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard let root = moved[sourceRoot.id] else { throw PoseError.incompatibleTopology }
        let dx = (root.x - sourceRoot.x) * scale, dy = (root.y - sourceRoot.y) * scale
        var cache: [Int: Joint] = [:], visiting = Set<Int>()
        func resolve(_ joint: Joint) throws -> Joint {
            if let point = cache[joint.id] { return point }
            guard visiting.insert(joint.id).inserted else { throw PoseError.cyclicSkeleton }
            var point = joint
            if let parent = joint.parent.flatMap({ targetPoints[$0] }) {
                let anchor = try resolve(parent)
                let x = joint.x - parent.x, y = joint.y - parent.y
                let length = hypot(x, y)
                var angle = atan2(y, x)
                if let id = mapping[joint.id], let after = moved[id],
                   let afterParent = after.parent.flatMap({ moved[$0] }) {
                    angle = atan2(after.y - afterParent.y, after.x - afterParent.x)
                    point.attributes["nativeAxisStretch"] = nil
                    point.attributes["nativeBoneLengthFactor"] = nil
                    if let factor = after.attributes["nativeBoneLengthFactor"] {
                        point.attributes["nativeBoneLengthFactor"] = factor
                    }
                }
                point.x = anchor.x + length * cos(angle)
                point.y = anchor.y + length * sin(angle)
            } else {
                point.x += dx; point.y += dy
            }
            guard point.x.isFinite, point.y.isFinite else { throw PoseError.incompatibleTopology }
            visiting.remove(joint.id)
            cache[joint.id] = point
            return point
        }
        var result = target
        result.joints = try target.joints.map(resolve)
        return result
    }

    private static func extent(_ unit: SceneUnit, root: Joint) -> Double {
        max(1, unit.joints.map { hypot($0.x - root.x, $0.y - root.y) }.max() ?? 1)
    }
}
