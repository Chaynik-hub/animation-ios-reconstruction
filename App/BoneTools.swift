import UIKit

enum PoseToolIcon {
    static func image(for id: String) -> UIImage? {
        guard ["prop_copy_pose", "prop_paste_pose", "prop_stretch_bone"].contains(id) else { return nil }
        return UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { renderer in
            let c = renderer.cgContext
            c.setStrokeColor(UIColor.original(0x00bd78).cgColor)
            c.setFillColor(UIColor.original(0x00bd78).cgColor)
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
    }

    func updateBoneButtons() {
        guard boneMode, handles, displayed == nil, ratio > 0,
              let (_, start, end) = selectedBone else {
            boneButtons.forEach { $0.isHidden = true }
            return
        }
        if boneButtons.isEmpty {
            for (index, label) in ["Удлинить кость", "Укоротить кость"].enumerated() {
                let button = UIButton(type: .system)
                button.tag = index
                button.accessibilityLabel = label
                button.setImage(UIImage(systemName: "arrow.right"), for: .normal)
                button.tintColor = .white
                button.backgroundColor = .original(0x00bd78)
                button.layer.cornerRadius = 19
                button.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragBone(_:))))
                addSubview(button)
                boneButtons.append(button)
            }
        }
        let angle = CGFloat(atan2(end.y - start.y, end.x - start.x))
        let anchor = CGPoint(x: end.x * ratio + origin.x, y: end.y * ratio + origin.y)
        for (index, button) in boneButtons.enumerated() {
            let side: CGFloat = index == 0 ? 26 : -26
            button.bounds = CGRect(x: 0, y: 0, width: 38, height: 38)
            button.center = CGPoint(
                x: min(max(20, anchor.x - sin(angle) * side), max(20, bounds.width - 20)),
                y: min(max(20, anchor.y + cos(angle) * side), max(20, bounds.height - 20))
            )
            button.transform = CGAffineTransform(rotationAngle: angle + (index == 0 ? 0 : .pi))
            button.isHidden = false
        }
    }

    @objc private func dragBone(_ gesture: UIPanGestureRecognizer) {
        guard let button = gesture.view as? UIButton else { return }
        switch gesture.state {
        case .began:
            guard let (unit, start, end) = selectedBone else { return }
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length > 0.001 else { return }
            boneDrag = (workspace.index, unit, end.id, length,
                        CGPoint(x: (end.x - start.x) / length, y: (end.y - start.y) / length), ratio)
            workspace.checkpoint()
        case .changed:
            guard let drag = boneDrag, drag.frame == workspace.index else { return }
            let delta = gesture.translation(in: self)
            let projection = Double(delta.x * drag.axis.x + delta.y * drag.axis.y) / Double(drag.ratio)
            let change = button.tag == 0 ? max(0, projection) : min(0, projection)
            let length = min(drag.length * 8, max(drag.length * 0.1, drag.length + change))
            if FrameManipulation.resizeBone(in: &workspace.document.frames[drag.frame], unitIndex: drag.unit,
                                           jointID: drag.joint, length: length) {
                updateBoneButtons()
                setNeedsDisplay()
            }
        case .ended, .cancelled, .failed:
            if boneDrag != nil { boneDrag = nil; workspace.notify() }
        default: break
        }
    }
}
