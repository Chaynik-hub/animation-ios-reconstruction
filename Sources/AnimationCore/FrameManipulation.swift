import Foundation

/// Slave references use SceneHelper.parsePointData's `unitName&pointID` encoding.
public enum FrameManipulation {
    public static func pastePose(_ pose: SceneUnit, into frame: inout SceneFrame, unitIndex: Int, includeRoot: Bool = true) -> Bool {
        guard frame.units.indices.contains(unitIndex) else { return false }
        var target = frame.units[unitIndex]
        let points = Dictionary(pose.joints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard target.name == pose.name, points.count == target.joints.count,
              target.joints.allSatisfy({ points[$0.id]?.id == $0.id && points[$0.id]?.parent == $0.parent })
        else { return false }
        var dx = 0.0, dy = 0.0
        if !includeRoot, let root = target.joints.first(where: { $0.attributes["base"] == "true" || $0.parent == nil }),
           let source = points[root.id] {
            dx = root.x - source.x
            dy = root.y - source.y
        }
        for index in target.joints.indices {
            guard let source = points[target.joints[index].id] else { return false }
            target.joints[index].x = source.x + dx
            target.joints[index].y = source.y + dy
            target.joints[index].attributes["nativeAxisStretch"] = source.attributes["nativeAxisStretch"]
            target.joints[index].attributes["nativeBoneLengthFactor"] = source.attributes["nativeBoneLengthFactor"]
        }
        for key in ["scale", "flipped"] { target.attributes[key] = pose.attributes[key] }
        func align(_ unit: inout SceneUnit, to anchor: Joint) {
            guard let base = unit.joints.first(where: { $0.attributes["base"] == "true" }) else { return }
            let dx = anchor.x - base.x, dy = anchor.y - base.y
            for index in unit.joints.indices {
                unit.joints[index].x += dx
                unit.joints[index].y += dy
            }
        }
        if let link = attachment(target),
           let parent = frame.units.first(where: { $0.name == link.0 }),
           let anchor = parent.joints.first(where: { $0.id == link.1 }) {
            align(&target, to: anchor)
        }
        frame.units[unitIndex] = target
        var pending = [unitIndex], visited = Set([unitIndex])
        while let parent = pending.popLast() {
            let master = frame.units[parent]
            for index in frame.units.indices where !visited.contains(index) {
                guard let link = attachment(frame.units[index]), link.0 == master.name,
                      let anchor = master.joints.first(where: { $0.id == link.1 }) else { continue }
                align(&frame.units[index], to: anchor)
                visited.insert(index)
                pending.append(index)
            }
        }
        return true
    }

    public static func boneLengthFactor(_ joint: Joint) -> Double {
        guard let value = Double(joint.attributes["nativeBoneLengthFactor"] ?? ""), value.isFinite else { return 1 }
        return min(8, max(0.1, value))
    }

    public static func setBoneLengthFactor(_ factor: Double, in frame: inout SceneFrame, unitIndex: Int, jointID: Int) -> Bool {
        guard frame.units.indices.contains(unitIndex), factor.isFinite,
              let index = frame.units[unitIndex].joints.firstIndex(where: { $0.id == jointID && $0.parent != nil }) else { return false }
        let bounded = min(8, max(0.1, factor))
        frame.units[unitIndex].joints[index].attributes["nativeBoneLengthFactor"] = bounded == 1 ? nil : String(bounded)
        return true
    }

    public static func resizeBone(in frame: inout SceneFrame, unitIndex: Int, jointID: Int, length: Double) -> Bool {
        guard frame.units.indices.contains(unitIndex), length.isFinite, length > 0 else { return false }
        var unit = frame.units[unitIndex]
        guard let end = unit.joints.first(where: { $0.id == jointID }),
              let start = unit.joints.first(where: { $0.id == end.parent }) else { return false }
        let current = hypot(end.x - start.x, end.y - start.y)
        guard current > 0.0001 else { return false }
        let factor = length / current - 1
        let dx = (end.x - start.x) * factor, dy = (end.y - start.y) * factor
        var affected = Set([jointID])
        var queue = [jointID]
        while let id = queue.popLast() {
            for child in unit.joints where child.parent == id {
                if affected.insert(child.id).inserted { queue.append(child.id) }
            }
        }
        for index in unit.joints.indices where affected.contains(unit.joints[index].id) {
            unit.joints[index].x += dx
            unit.joints[index].y += dy
            if unit.joints[index].id == jointID {
                unit.joints[index].attributes["nativeAxisStretch"] = "true"
                unit.joints[index].attributes["nativeBoneLengthFactor"] = nil
            }
        }
        return pastePose(unit, into: &frame, unitIndex: unitIndex)
    }

    static func attachment(_ unit:SceneUnit)->(String,Int)? {
        guard let base=unit.joints.first(where:{$0.attributes["base"]=="true"}),base.attributes["attachable"]=="slave",let raw=base.attributes["attached"] else{return nil}
        let pieces=raw.components(separatedBy:"&")
        guard pieces.count==2,pieces[0] != "null",let id=Int(pieces[1]),id>=0 else{return nil}
        return (pieces[0],id)
    }
    @discardableResult public static func attachNearby(_ frame:inout SceneFrame,unitIndex:Int,radius:Double)->Bool {
        guard frame.units.indices.contains(unitIndex),attachment(frame.units[unitIndex])==nil,
              let baseIndex=frame.units[unitIndex].joints.firstIndex(where:{$0.attributes["base"]=="true" && $0.attributes["attachable"]=="slave"}) else{return false}
        let base=frame.units[unitIndex].joints[baseIndex]
        var connected=Set([unitIndex]),changed=true
        while changed {
            changed=false
            for i in frame.units.indices {
                guard let link=attachment(frame.units[i]),let parent=frame.units.firstIndex(where:{$0.name==link.0}) else{continue}
                if connected.contains(i) || connected.contains(parent) {if connected.insert(i).inserted{changed=true};if connected.insert(parent).inserted{changed=true}}
            }
        }
        var candidate:(Int,Joint)?;var distance=radius
        for i in frame.units.indices where !connected.contains(i) {
            for point in frame.units[i].joints where point.attributes["attachable"]=="master" {
                let name=frame.units[i].name
                let occupied=frame.units.contains{unit in guard let link=attachment(unit) else{return false};return link.0==name && link.1==point.id}
                let d=hypot(point.x-base.x,point.y-base.y)
                if !occupied && d<=distance {distance=d;candidate=(i,point)}
            }
        }
        guard let (masterIndex,point)=candidate else{return false}
        let dx=point.x-base.x,dy=point.y-base.y
        for i in connected {for j in frame.units[i].joints.indices {frame.units[i].joints[j].x+=dx;frame.units[i].joints[j].y+=dy}}
        frame.units[unitIndex].joints[baseIndex].attributes["attached"]=frame.units[masterIndex].name+"&"+String(point.id)
        return true
    }
    public static func move(_ frame:inout SceneFrame,unitIndex:Int,jointID:Int,x:Double,y:Double,stretch:Bool=false)throws {
        guard frame.units.indices.contains(unitIndex),let oldPoint=frame.units[unitIndex].joints.first(where:{$0.id==jointID}) else{throw PoseError.incompatibleTopology}
        let before=frame.units[unitIndex]
        let base=oldPoint.attributes["base"]=="true"
        if base,let link=attachment(before),frame.units.contains(where:{$0.name==link.0 && $0.joints.contains(where:{$0.id==link.1})}){return}
        try JointManipulation.move(&frame.units[unitIndex],jointID:jointID,x:x,y:y,stretch:stretch)
        if !base,oldPoint.attributes["kinstart"]=="true" {
            // PointManipulator.kinematicMove calls moveToMaster for every slave:
            // unlike a rigid branch rotation, this translates each attachment to
            // its own newly solved anchor without rotating the held object.
            var visited=Set([unitIndex]),pending=[unitIndex]
            while let master=pending.popLast() {
                for i in frame.units.indices where !visited.contains(i) {
                    guard let link=attachment(frame.units[i]),link.0==frame.units[master].name,
                          let anchor=frame.units[master].joints.first(where:{$0.id==link.1}),
                          let base=frame.units[i].joints.first(where:{$0.attributes["base"]=="true"}) else{continue}
                    let dx=anchor.x-base.x,dy=anchor.y-base.y
                    for j in frame.units[i].joints.indices {frame.units[i].joints[j].x+=dx;frame.units[i].joints[j].y+=dy}
                    visited.insert(i);pending.append(i)
                }
            }
            return
        }
        guard let after=frame.units[unitIndex].joints.first(where:{$0.id==jointID}) else{return}
        let deltaX=after.x-oldPoint.x,deltaY=after.y-oldPoint.y
        var affected=Set(before.joints.filter { old in
            guard let now=frame.units[unitIndex].joints.first(where:{$0.id==old.id}) else{return false}
            return abs(now.x-old.x)>1e-10 || abs(now.y-old.y)>1e-10
        }.map(\.id))
        affected.insert(jointID)
        let pivot=before.joints.first(where:{$0.id==oldPoint.parent}) ?? oldPoint
        let translates=base || (stretch && oldPoint.attributes["stretchable"]=="true")
        let angle=translates ? 0:atan2(after.y-pivot.y,after.x-pivot.x)-atan2(oldPoint.y-pivot.y,oldPoint.x-pivot.x)
        let cosine=cos(angle),sine=sin(angle)
        var visited=Set([unitIndex])
        var pending:[(String,Set<Int>)]=[(before.name,affected)]
        while !pending.isEmpty {
            let (master,ids)=pending.removeLast()
            for i in frame.units.indices where !visited.contains(i) {
                guard let link=attachment(frame.units[i]),link.0==master,ids.contains(link.1) else{continue}
                visited.insert(i)
                for j in frame.units[i].joints.indices {
                    if translates {frame.units[i].joints[j].x+=deltaX;frame.units[i].joints[j].y+=deltaY}
                    else {
                        let dx=frame.units[i].joints[j].x-pivot.x,dy=frame.units[i].joints[j].y-pivot.y
                        frame.units[i].joints[j].x=pivot.x+dx*cosine-dy*sine
                        frame.units[i].joints[j].y=pivot.y+dx*sine+dy*cosine
                    }
                }
                pending.append((frame.units[i].name,Set(frame.units[i].joints.map(\.id))))
            }
        }
    }
}
