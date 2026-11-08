import Foundation

/// Transfers changes in joint angles and root travel to a different rig.
public struct MotionRetarget {
    private let source: SceneUnit
    private let target: SceneUnit
    private let sourceRoot: Joint
    private let targetRoot: Joint
    private let mapping: [Int: Int]
    private let scale: Double
    private let compatible: Bool
    private let sourceRest: [Int: Joint]
    private let targetRest: [Int: Joint]

    public init?(source: SceneUnit, target: SceneUnit, sourceReference: SceneUnit? = nil, targetReference: SceneUnit? = nil) {
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
        var result: [Int: Int] = [b.id: a.id]
        let sourcePoints = Dictionary((sourceReference ?? source).joints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let targetPoints = Dictionary((targetReference ?? target).joints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        sourceRest = sourcePoints
        targetRest = targetPoints
        var pending = target.joints.filter { $0.parent != nil }
        var visited = Set([b.id])
        while !pending.isEmpty {
            let ready = pending.filter { $0.parent.map(visited.contains) == true }
            if ready.isEmpty { break }
            for joint in ready {
                visited.insert(joint.id)
                guard let parent = joint.parent, let sourceParent = result[parent] else { continue }
                let used = Set(result.values)
                let candidates = source.joints.filter { $0.parent == sourceParent && !used.contains($0.id) }
                if same, candidates.contains(where: { $0.id == joint.id }) {
                    result[joint.id] = joint.id
                } else if let name = joint.attributes["name"], !name.isEmpty,
                          let match = candidates.first(where: { $0.attributes["name"] == name }) {
                    result[joint.id] = match.id
                } else if let from = sourcePoints[sourceParent], let to = targetPoints[parent] {
                    let rest = targetPoints[joint.id] ?? joint
                    let tx = rest.x - to.x, ty = rest.y - to.y
                    let targetAngle = atan2(ty, tx)
                    let targetLength = hypot(tx, ty) / targetHeight
                    func score(_ candidate: Joint) -> Double {
                        let point = sourcePoints[candidate.id] ?? candidate
                        let sx = point.x - from.x, sy = point.y - from.y
                        let angle = atan2(sy, sx) - targetAngle
                        let length = hypot(sx, sy) / sourceHeight
                        let sourceChildren = source.joints.filter { $0.parent == candidate.id }.count
                        let targetChildren = target.joints.filter { $0.parent == joint.id }.count
                        return 1 - cos(angle) + abs(length - targetLength) + 0.25 * Double(abs(sourceChildren - targetChildren))
                    }
                    if let match = candidates.min(by: { score($0) < score($1) }) {
                        result[joint.id] = match.id
                    }
                }
            }
            pending.removeAll { visited.contains($0.id) }
        }
        compatible = same || (sourceReference == nil && targetReference == nil && result.count == target.joints.count && result.count == source.joints.count)
        mapping = result
    }

    public func pose(_ sample: SceneUnit) throws -> SceneUnit {
        let original = sourceRest
        let moved = Dictionary(sample.joints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let targetPoints = Dictionary(target.joints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard let root = moved[sourceRoot.id] else { throw PoseError.incompatibleTopology }
        let dx = (root.x - sourceRoot.x) * scale, dy = (root.y - sourceRoot.y) * scale
        var cache: [Int: Joint] = [:], visiting = Set<Int>()
        var rotations: [Int: Double] = [:]
        func resolve(_ joint: Joint) throws -> Joint {
            if let point = cache[joint.id] { return point }
            guard visiting.insert(joint.id).inserted else { throw PoseError.cyclicSkeleton }
            var point = joint
            if let parent = joint.parent.flatMap({ targetPoints[$0] }) {
                let anchor = try resolve(parent)
                let x = joint.x - parent.x, y = joint.y - parent.y
                let length = hypot(x, y)
                let base = targetRest[joint.id] ?? joint
                let baseParent = targetRest[parent.id] ?? parent
                let restAngle = atan2(base.y - baseParent.y, base.x - baseParent.x)
                var angle = restAngle + (rotations[parent.id] ?? 0)
                if let id = mapping[joint.id], let after = moved[id],
                   let afterParent = after.parent.flatMap({ moved[$0] }) {
                    let recorded = atan2(after.y - afterParent.y, after.x - afterParent.x)
                    if compatible {
                        angle = recorded
                        point.attributes["nativeAxisStretch"] = nil
                        point.attributes["nativeBoneLengthFactor"] = after.attributes["nativeBoneLengthFactor"]
                    } else if let before = original[id], let prior = before.parent.flatMap({ original[$0] }) {
                        angle = restAngle + recorded - atan2(before.y - prior.y, before.x - prior.x)
                    }
                }
                rotations[joint.id] = angle - restAngle
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
