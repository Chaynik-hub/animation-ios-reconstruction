import Foundation

/// Contact-based motion for side-view rigs with two legs sharing a pelvis.
public struct GroundedMotion {
    public enum Action { case walk, run, jump, crouch }
    private struct Leg {
        let knee: Joint
        let foot: Joint
        let upper: Double
        let lower: Double
    }
    private let source: SceneUnit
    private let pelvis: Joint
    private let legs: [Leg]
    private let height: Double

    public init?(unit: SceneUnit) {
        let joints = Dictionary(unit.joints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let bottom = unit.joints.map(\.y).max() ?? 0
        let top = unit.joints.map(\.y).min() ?? 0
        let height = bottom - top
        guard height.isFinite, height > 10 else { return nil }
        var groups: [Int: [Leg]] = [:]
        for foot in unit.joints where foot.y >= bottom - height * 0.12 {
            guard let knee = foot.parent.flatMap({ joints[$0] }),
                  let hip = knee.parent.flatMap({ joints[$0] }),
                  hip.y < knee.y, knee.y < foot.y,
                  foot.y - hip.y > height * 0.27 else { continue }
            let upper = hypot(knee.x - hip.x, knee.y - hip.y)
            let lower = hypot(foot.x - knee.x, foot.y - knee.y)
            if min(upper, lower) > 1 {
                groups[hip.id, default: []].append(Leg(knee: knee, foot: foot, upper: upper, lower: lower))
            }
        }
        for hip in groups.keys.sorted() {
            guard let root = joints[hip], let choices = groups[hip] else { continue }
            let feet = choices.sorted { $0.foot.x < $1.foot.x }
            if let first = feet.first, let second = feet.last,
               first.knee.id != second.knee.id, second.foot.x - first.foot.x > height * 0.025 {
                self.source = unit
                self.pelvis = root
                self.legs = [first, second]
                self.height = height
                return
            }
        }
        return nil
    }

    public func pose(_ action: Action, progress: Double, direction: Double) -> SceneUnit {
        let t = min(1, max(0, progress))
        guard t > 0 else { return source }
        let direction = direction < 0 ? -1.0 : 1.0
        var x = 0.0, y = 0.0
        var armSwing = 0.0
        var footOffsets = [(0.0, 0.0), (0.0, 0.0)]
        switch action {
        case .walk, .run:
            let stepCount = action == .run ? 6 : 4
            let stride = height * (action == .run ? 0.14 : 0.10)
            let phase = t * Double(stepCount)
            let step = min(stepCount - 1, Int(phase))
            let u = phase - Double(step)
            armSwing = sin(.pi * phase) * sin(.pi * t) * (action == .run ? 0.65 : 0.38)
            x = direction * stride * (Double(step) + smooth(u))
            y = height * 0.032 * sin(.pi * u) + height * 0.025 * sin(.pi * t)
            for side in 0..<2 {
                let priorSwings = (step + (side == 0 ? 1 : 0)) / 2
                let moving = step % 2 == side
                let travel = Double(priorSwings) + (moving ? smooth(u) : 0)
                footOffsets[side] = (direction * stride * 2 * travel,
                                     moving ? -height * (action == .run ? 0.12 : 0.065) * pow(sin(.pi * u), 2) : 0)
            }
        case .jump:
            let takeoff = 0.29, landing = 0.76
            armSwing = 0.45 * sin(2 * .pi * t)
            if t < takeoff {
                let u = t / takeoff
                y = height * 0.12 * pow(sin(.pi * u), 2)
            } else if t <= landing {
                let u = (t - takeoff) / (landing - takeoff)
                x = direction * height * 0.22 * u
                y = -height * 0.30 * 4 * u * (1 - u)
                let tuck = -height * 0.08 * pow(sin(.pi * u), 2)
                footOffsets = [(x, y + tuck), (x, y + tuck)]
            } else {
                x = direction * height * 0.22
                y = height * 0.10 * pow(sin(.pi * (t - landing) / (1 - landing)), 2)
                footOffsets = [(x, 0), (x, 0)]
            }
        case .crouch:
            y = height * 0.19 * smooth(min(1, min(t / 0.35, (1 - t) / 0.4)))
        }

        // Lower the hips if either planted ankle would otherwise be out of reach.
        for (index, leg) in legs.enumerated() {
            let targetX = leg.foot.x + footOffsets[index].0
            let targetY = leg.foot.y + footOffsets[index].1
            let horizontal = targetX - (pelvis.x + x)
            let reach = leg.upper + leg.lower
            let vertical = sqrt(max(0, reach * reach - horizontal * horizontal))
            y = max(y, targetY - pelvis.y - vertical)
        }
        var unit = source
        for index in unit.joints.indices {
            unit.joints[index].x += x
            unit.joints[index].y += y
        }
        let torso = source.joints.filter { $0.parent == pelvis.id && $0.y < pelvis.y }.min { $0.y < $1.y }
        if let torso, armSwing != 0 {
            let arms = source.joints.filter { $0.parent == torso.id && $0.y > torso.y && abs($0.x - torso.x) > height * 0.035 }
            for arm in arms {
                let angle = armSwing * (arm.x < torso.x ? -direction : direction)
                let cosine = cos(angle), sine = sin(angle)
                for joint in descendants(of: arm.id, in: unit, includingRoot: true) {
                    let dx = unit.joints[joint].x - (torso.x + x)
                    let dy = unit.joints[joint].y - (torso.y + y)
                    unit.joints[joint].x = torso.x + x + dx * cosine - dy * sine
                    unit.joints[joint].y = torso.y + y + dx * sine + dy * cosine
                }
            }
        }
        for (index, leg) in legs.enumerated() {
            let hipX = pelvis.x + x, hipY = pelvis.y + y
            let targetX = leg.foot.x + footOffsets[index].0
            let targetY = leg.foot.y + footOffsets[index].1
            let dx = targetX - hipX, dy = targetY - hipY
            let length = hypot(dx, dy)
            guard length > 0.001 else { continue }
            let reach = min(leg.upper + leg.lower, max(abs(leg.upper - leg.lower) + 0.001, length))
            let vx = dx / length, vy = dy / length
            let along = (leg.upper * leg.upper - leg.lower * leg.lower + reach * reach) / (2 * reach)
            let bend = sqrt(max(0, leg.upper * leg.upper - along * along))
            let originalCross = (leg.knee.x - pelvis.x) * (leg.foot.y - pelvis.y)
                - (leg.knee.y - pelvis.y) * (leg.foot.x - pelvis.x)
            let sign = abs(originalCross) > 0.01 ? (originalCross > 0 ? 1.0 : -1.0) : direction
            let kneeX = hipX + vx * along + vy * bend * sign
            let kneeY = hipY + vy * along - vx * bend * sign
            let footX = hipX + vx * reach, footY = hipY + vy * reach
            for joint in descendants(of: leg.foot.id, in: unit, includingRoot: false) {
                unit.joints[joint].x += footX - (leg.foot.x + x)
                unit.joints[joint].y += footY - (leg.foot.y + y)
            }
            for joint in unit.joints.indices {
                if unit.joints[joint].id == leg.knee.id {
                    unit.joints[joint].x = kneeX; unit.joints[joint].y = kneeY
                } else if unit.joints[joint].id == leg.foot.id {
                    unit.joints[joint].x = footX; unit.joints[joint].y = footY
                }
            }
        }
        return unit
    }

    private func descendants(of id: Int, in unit: SceneUnit, includingRoot: Bool) -> [Int] {
        var pending = [id], seen: Set<Int> = [id]
        while let parent = pending.popLast() {
            for joint in unit.joints where joint.parent == parent {
                if seen.insert(joint.id).inserted { pending.append(joint.id) }
            }
        }
        if !includingRoot { seen.remove(id) }
        return unit.joints.indices.filter { seen.contains(unit.joints[$0].id) }
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}
