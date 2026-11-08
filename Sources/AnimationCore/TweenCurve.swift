import Foundation

public enum TweenCurve: String, CaseIterable {
    case linear = "Linear", expo = "In-Out Expo", bounceIn = "In Bounce", bounce = "Bounce"
    case back = "In-Out Back", inQuint = "In Quint", outQuint = "Out Quint"
    case shakeX = "Shake X", shakeY = "Shake Y", cartwheelCW = "Вращение вправо", cartwheelCCW = "Вращение влево"

    public var isCartwheel: Bool { self == .cartwheelCW || self == .cartwheelCCW }
    public var isShake: Bool { self == .shakeX || self == .shakeY }

    public func progress(_ t: Double, strength: Double) -> Double {
        let t = min(1, max(0, t))
        guard t > 0, t < 1 else { return t }
        let eased: Double
        switch self {
        case .expo: eased = t < 0.5 ? pow(2, 20 * t - 10) / 2 : (2 - pow(2, 10 - 20 * t)) / 2
        case .bounceIn: eased = 1 - Self.outBounce(1 - t)
        case .bounce: eased = Self.outBounce(t)
        case .back:
            let c = 1.70158 * 1.525
            let u = t < 0.5 ? 2 * t : 2 * t - 2
            eased = t < 0.5 ? u * u * ((c + 1) * u - c) / 2 : (u * u * ((c + 1) * u + c) + 2) / 2
        case .inQuint: eased = pow(t, 5)
        case .outQuint: eased = 1 - pow(1 - t, 5)
        default: eased = t
        }
        return t + (eased - t) * min(1, max(0, strength))
    }

    private static func outBounce(_ t: Double) -> Double {
        let d = 2.75, n = 7.5625
        if t < 1 / d { return n * t * t }
        if t < 2 / d { let u = t - 1.5 / d; return n * u * u + 0.75 }
        if t < 2.5 / d { let u = t - 2.25 / d; return n * u * u + 0.9375 }
        let u = t - 2.625 / d
        return n * u * u + 0.984375
    }

    public func pose(from first: SceneUnit, to last: SceneUnit, at t: Double,
                     strength: Double, frequency: Double) throws -> SceneUnit {
        if t <= 0 { return first }; if t >= 1 { return last }
        let eased = progress(t, strength: strength)
        var unit = try PoseInterpolation.between(first, last, progress: eased, extrapolate: true)
        if isShake {
            let start = first.joints.first { $0.parent == nil }
            let end = last.joints.first { $0.parent == nil }
            let travel = self == .shakeX ? abs((end?.x ?? 0) - (start?.x ?? 0)) : abs((end?.y ?? 0) - (start?.y ?? 0))
            let offset = sin(t * frequency * 2 * .pi) * max(12, travel * 0.15) * min(1, max(0, strength)) * 1.5
            for index in unit.joints.indices {
                if self == .shakeX { unit.joints[index].x += offset }
                else { unit.joints[index].y += offset }
            }
        } else if isCartwheel,
                  let root = unit.joints.first(where: { $0.parent == nil }) {
            let spin = t + (t * t * (3 - 2 * t) - t) * min(1, max(0, strength))
            let turns = min(12, max(1, frequency))
            let angle = spin * turns * 2 * .pi * (self == .cartwheelCW ? 1 : -1)
            let c = cos(angle), s = sin(angle)
            for index in unit.joints.indices {
                let x = unit.joints[index].x - root.x, y = unit.joints[index].y - root.y
                unit.joints[index].x = root.x + x * c - y * s
                unit.joints[index].y = root.y + x * s + y * c
            }
        }
        return unit
    }
}
