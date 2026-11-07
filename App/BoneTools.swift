import UIKit

enum PoseToolIcon {
    static func image(for id: String) -> UIImage? {
        guard ["prop_copy_pose", "prop_paste_pose", "prop_stretch_bone"].contains(id) else { return nil }
        return UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { renderer in
            let c = renderer.cgContext
            c.setStrokeColor(UIColor.white.cgColor)
            c.setFillColor(UIColor.white.cgColor)
            c.setLineWidth(2.5)
            c.setLineCap(.round)
            c.setLineJoin(.round)
            func line(_ points: CGPoint...) {
                c.beginPath()
                c.addLines(between: points)
                c.strokePath()
            }
            if id == "prop_stretch_bone" {
                line(CGPoint(x: 6, y: 23), CGPoint(x: 25, y: 9))
                line(CGPoint(x: 13, y: 23), CGPoint(x: 6, y: 23), CGPoint(x: 8, y: 16))
                line(CGPoint(x: 18, y: 9), CGPoint(x: 25, y: 9), CGPoint(x: 23, y: 16))
                return
            }
            let joints = [CGPoint(x: 5, y: 23), CGPoint(x: 12, y: 14), CGPoint(x: 10, y: 6)]
            c.addLines(between: joints)
            c.strokePath()
            for point in joints { c.fillEllipse(in: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)) }
            let copy = id == "prop_copy_pose"
            let tip: CGFloat = copy ? 28 : 16
            let tail: CGFloat = copy ? 16 : 28
            let wing: CGFloat = copy ? 23 : 21
            line(CGPoint(x: tail, y: 19), CGPoint(x: tip, y: 19))
            line(CGPoint(x: wing, y: 14), CGPoint(x: tip, y: 19), CGPoint(x: wing, y: 24))
        }.withRenderingMode(.alwaysOriginal)
    }
}

extension SceneCanvas {
    private var selectedBone: (Int, Joint, Joint)? {
        guard let unit = workspace.selected, workspace.frame.units.indices.contains(unit),
              let end = workspace.frame.units[unit].joints.first(where: { $0.id == boneJoint }),
              let start = workspace.frame.units[unit].joints.first(where: { $0.id == end.parent })
        else { return nil }
        return (unit, start, end)
    }

    func selectBone(at screen: CGPoint) {
        guard ratio > 0, let index = workspace.selected, workspace.frame.units.indices.contains(index) else { return }
        let unit = workspace.frame.units[index]
        var nearest: CGFloat = 24
        boneJoint = nil
        for end in unit.joints {
            guard let start = unit.joints.first(where: { $0.id == end.parent }) else { continue }
            let a = CGPoint(x: start.x * ratio + origin.x, y: start.y * ratio + origin.y)
            let dx = CGFloat(end.x - start.x) * ratio, dy = CGFloat(end.y - start.y) * ratio
            let squared = dx * dx + dy * dy
            guard squared > 1 else { continue }
            let fraction = min(1, max(0, ((screen.x - a.x) * dx + (screen.y - a.y) * dy) / squared))
            let distance = hypot(screen.x - (a.x + fraction * dx), screen.y - (a.y + fraction * dy))
            if distance < nearest { nearest = distance; boneJoint = end.id }
        }
        updateBoneButtons()
        setNeedsDisplay()
        workspace.notify()
    }

    func updateBoneButtons() {
        guard boneMode, handles, displayed == nil, ratio > 0,
              let (_, start, end) = selectedBone else {
            boneButtons.forEach { $0.isHidden = true }
            return
        }
        if boneButtons.isEmpty {
            let button = UIButton(type: .system)
            button.accessibilityLabel = "Изменить длину кости"
            button.setImage(UIImage(systemName: "arrow.left.and.right"), for: .normal)
            button.tintColor = .white
            button.backgroundColor = .original(0x00bd78)
            button.layer.cornerRadius = 19
            button.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragBone(_:))))
            addSubview(button)
            boneButtons.append(button)
        }
        let angle = CGFloat(atan2(end.y - start.y, end.x - start.x))
        let tip = boneTip(start: start, end: end)
        let anchor = CGPoint(x: tip.x * ratio + origin.x, y: tip.y * ratio + origin.y)
        for button in boneButtons {
            let side: CGFloat = 26
            button.bounds = CGRect(x: 0, y: 0, width: 38, height: 38)
            button.center = CGPoint(
                x: min(max(20, anchor.x - sin(angle) * side), max(20, bounds.width - 20)),
                y: min(max(20, anchor.y + cos(angle) * side), max(20, bounds.height - 20))
            )
            button.transform = CGAffineTransform(rotationAngle: angle)
            button.isHidden = false
        }
    }

    func paintSelectedBone(in context: CGContext) {
        guard boneMode, ratio > 0, let (_, start, end) = selectedBone else { return }
        context.saveGState()
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2 / ratio)
        context.beginPath()
        context.move(to: CGPoint(x: start.x, y: start.y))
        context.addLine(to: boneTip(start: start, end: end))
        context.strokePath()
        context.restoreGState()
    }

    func boneTip(start: Joint, end: Joint) -> CGPoint {
        let factor = FrameManipulation.boneLengthFactor(end)
        return CGPoint(x: start.x + (end.x - start.x) * factor, y: start.y + (end.y - start.y) * factor)
    }

    var canResetBoneLength: Bool {
        guard let (_, _, end) = selectedBone else { return false }
        return FrameManipulation.boneLengthFactor(end) != 1 || end.attributes["nativeAxisStretch"] == "true"
    }

    func resetBoneLength() {
        guard let (unitIndex, start, end) = selectedBone, canResetBoneLength else { return }
        var frame = workspace.frame
        if end.attributes["nativeAxisStretch"] == "true" {
            let unit = frame.units[unitIndex]
            let definition = workspace.catalog.first { $0.name == UnitIdentity.baseName(unit.name) }
            func point(_ id: Int) -> CGPoint? {
                guard let value = definition?.points.first(where: { $0["id"] == String(id) }),
                      let x = Double(value["x"] ?? ""), let y = Double(value["y"] ?? "") else { return nil }
                return CGPoint(x: x, y: y)
            }
            if let a = point(start.id), let b = point(end.id) {
                let length = Double(hypot(b.x - a.x, b.y - a.y)) * (Double(unit.attributes["scale"] ?? "") ?? 1)
                _ = FrameManipulation.resizeBone(in: &frame, unitIndex: unitIndex, jointID: end.id, length: length)
            }
            if let index = frame.units[unitIndex].joints.firstIndex(where: { $0.id == end.id }) {
                frame.units[unitIndex].joints[index].attributes["nativeAxisStretch"] = nil
            }
        }
        guard FrameManipulation.setBoneLengthFactor(1, in: &frame, unitIndex: unitIndex, jointID: end.id) else { return }
        workspace.checkpoint()
        workspace.document.frames[workspace.index] = frame
        workspace.notify()
    }

    @objc private func dragBone(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            guard let (unit, start, end) = selectedBone else { return }
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length > 0.001 else { return }
            boneDrag = (workspace.index, unit, end.id, length * FrameManipulation.boneLengthFactor(end),
                        CGPoint(x: (end.x - start.x) / length, y: (end.y - start.y) / length), ratio)
            workspace.checkpoint()
        case .changed:
            guard let drag = boneDrag, drag.frame == workspace.index else { return }
            let delta = gesture.translation(in: self)
            let projection = Double(delta.x * drag.axis.x + delta.y * drag.axis.y) / Double(drag.ratio)
            guard let (_, start, end) = selectedBone, end.id == drag.joint else { return }
            let original = hypot(end.x - start.x, end.y - start.y)
            guard original > 0.001 else { return }
            let factor = (drag.length + projection) / original
            if FrameManipulation.setBoneLengthFactor(factor, in: &workspace.document.frames[drag.frame],
                                                     unitIndex: drag.unit, jointID: drag.joint) {
                updateBoneButtons()
                setNeedsDisplay()
            }
        case .ended, .cancelled, .failed:
            if boneDrag != nil { boneDrag = nil; workspace.notify() }
        default: break
        }
    }
}
