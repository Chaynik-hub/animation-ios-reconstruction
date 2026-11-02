import UIKit

extension SceneCanvas {
    func selectedArtworkBounds() -> CGRect? {
        guard let selected = workspace.selected, workspace.frame.units.indices.contains(selected) else { return nil }
        var result = CGRect.null
        for index in UnitEditing.descendants(in: workspace.frame, of: selected) {
            let unit = workspace.frame.units[index]
            let joints = Dictionary(unit.joints.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
            for joint in unit.joints { result = result.union(CGRect(x: joint.x, y: joint.y, width: 0.001, height: 0.001)) }
            guard let definition = workspace.catalog.first(where: { $0.name == UnitIdentity.baseName(unit.name) }) else { continue }
            let scale = Double(unit.attributes["scale"] ?? "1") ?? 1
            let flipped = unit.attributes["flipped"] == "true"
            let state = Int(unit.attributes["state"] ?? "0") ?? 0
            let groups = Dictionary(grouping: definition.parts, by: { ($0["start"] ?? "") + ":" + ($0["end"] ?? "") })
            for candidates in groups.values {
                let matching = candidates.filter { ($0["flipped"] == "true") == flipped }
                let variants = matching.isEmpty ? candidates.filter { $0["flipped"] != "true" } : matching
                guard let part = variants.first(where: { (Int($0["state"] ?? "0") ?? 0) == state }) ?? variants.first(where: { (Int($0["state"] ?? "0") ?? 0) == 0 }),
                      let start = Int(part["start"] ?? ""), let end = Int(part["end"] ?? ""), let a = joints[start], let b = joints[end], let path = part["image"], let bitmap = image(path) else { continue }
                var stretch = 1.0
                if b.attributes["stretchable"] == "true", scale > 0,
                   let pa = definition.points.first(where: { $0["id"] == String(start) }), let pb = definition.points.first(where: { $0["id"] == String(end) }),
                   let ax = Double(pa["x"] ?? ""), let ay = Double(pa["y"] ?? ""), let bx = Double(pb["x"] ?? ""), let by = Double(pb["y"] ?? "") {
                    let rest = hypot(bx - ax, by - ay) * scale
                    if rest > 0 { stretch = hypot(b.x - a.x, b.y - a.y) / rest }
                }
                let transform = CGAffineTransform(translationX: a.x, y: a.y).rotated(by: atan2(b.y - a.y, b.x - a.x)).scaledBy(x: scale * stretch, y: flipped && part["flipped"] != "true" ? -scale : scale)
                let rectangle = CGRect(x: Double(part["x_offset"] ?? "0") ?? 0, y: Double(part["y_offset"] ?? "0") ?? 0, width: bitmap.size.width, height: bitmap.size.height)
                result = result.union(rectangle.applying(transform))
            }
        }
        guard !result.isNull, result.minX.isFinite, result.maxX.isFinite, result.minY.isFinite, result.maxY.isFinite else { return nil }
        if result.width < 60 { result = result.insetBy(dx: -30, dy: 0) }
        if result.height < 60 { result = result.insetBy(dx: 0, dy: -30) }
        return result
    }
}
