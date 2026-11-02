import Foundation

/// Slave references use SceneHelper.parsePointData's `unitName&pointID` encoding.
public enum FrameManipulation {
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
    public static func move(_ frame:inout SceneFrame,unitIndex:Int,jointID:Int,x:Double,y:Double)throws {
        guard frame.units.indices.contains(unitIndex),let oldPoint=frame.units[unitIndex].joints.first(where:{$0.id==jointID}) else{throw PoseError.incompatibleTopology}
        let before=frame.units[unitIndex]
        let base=oldPoint.attributes["base"]=="true"
        if base,let link=attachment(before),frame.units.contains(where:{$0.name==link.0 && $0.joints.contains(where:{$0.id==link.1})}){return}
        try JointManipulation.move(&frame.units[unitIndex],jointID:jointID,x:x,y:y)
        guard let after=frame.units[unitIndex].joints.first(where:{$0.id==jointID}) else{return}
        let deltaX=after.x-oldPoint.x,deltaY=after.y-oldPoint.y
        var affected=Set(before.joints.filter { old in
            guard let now=frame.units[unitIndex].joints.first(where:{$0.id==old.id}) else{return false}
            return abs(now.x-old.x)>1e-10 || abs(now.y-old.y)>1e-10
        }.map(\.id))
        affected.insert(jointID)
        let pivot=before.joints.first(where:{$0.id==oldPoint.parent}) ?? oldPoint
        let angle=base ? 0:atan2(after.y-pivot.y,after.x-pivot.x)-atan2(oldPoint.y-pivot.y,oldPoint.x-pivot.x)
        let cosine=cos(angle),sine=sin(angle)
        var visited=Set([unitIndex])
        var pending:[(String,Set<Int>)]=[(before.name,affected)]
        while !pending.isEmpty {
            let (master,ids)=pending.removeLast()
            for i in frame.units.indices where !visited.contains(i) {
                guard let link=attachment(frame.units[i]),link.0==master,ids.contains(link.1) else{continue}
                visited.insert(i)
                for j in frame.units[i].joints.indices {
                    if base {frame.units[i].joints[j].x+=deltaX;frame.units[i].joints[j].y+=deltaY}
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
