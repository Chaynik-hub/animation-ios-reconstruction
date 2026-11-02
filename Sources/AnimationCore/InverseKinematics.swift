import Foundation

/// FABRIK's two passes and branch transforms follow the retained Android implementation.
/// The chain ends at the first base/fixed/kinstop joint; no bone is stretched to reach a target.
public enum InverseKinematics {
    private struct Bone {
        let start:Int
        let end:Int
        let length:Double
        let angle:Double
        let staticDescendants:Set<Int>
    }
    @discardableResult public static func solve(_ unit:inout SceneUnit,jointID:Int,x:Double,y:Double)throws->Bool {
        guard x.isFinite,y.isFinite,let effector=unit.joints.firstIndex(where:{$0.id==jointID}) else{throw PoseError.incompatibleTopology}
        if abs(unit.joints[effector].x-x)<1 && abs(unit.joints[effector].y-y)<1{return true}
        let original=unit.joints
        let ids=Dictionary(original.enumerated().map{($0.element.id,$0.offset)},uniquingKeysWith:{$1})
        guard ids.count==original.count else{throw PoseError.incompatibleTopology}
        var chain=[effector],seen=Set([effector])
        while let last=chain.last,!stops(original[last]) {
            guard let parent=original[last].parent.flatMap({ids[$0]}),seen.insert(parent).inserted else{throw PoseError.incompatibleTopology}
            chain.append(parent)
        }
        guard chain.count>1,let root=chain.last else{return false}
        func descendants(_ index:Int)->Set<Int> {
            var found=Set<Int>(),pending=[index]
            while let next=pending.popLast() {
                for i in original.indices where original[i].parent==original[next].id && i != index {
                    if found.insert(i).inserted{pending.append(i)}
                }
            }
            return found
        }
        let bones=(0..<(chain.count-1)).map{ i -> Bone in
            let end=chain[i],start=chain[i+1]
            var branch=descendants(end)
            if i>0 {branch.subtract(descendants(chain[i-1]));branch.remove(chain[i-1])}
            return Bone(start:start,end:end,length:hypot(original[end].x-original[start].x,original[end].y-original[start].y),angle:atan2(original[end].y-original[start].y,original[end].x-original[start].x),staticDescendants:branch)
        }
        guard bones.allSatisfy({$0.length.isFinite && $0.length>1e-9}) else{throw PoseError.incompatibleTopology}
        var points=original,orientations=Array(repeating:0.0,count:original.count)
        func angle(_ b:Bone)->Double{atan2(points[b.end].y-points[b.start].y,points[b.end].x-points[b.start].x)}
        func violation(_ index:Int)->Double? {
            let joint=original[index]
            guard joint.attributes["base"] != "true",joint.attributes["minRotation"] != nil || joint.attributes["maxRotation"] != nil,
                  let parent=joint.parent.flatMap({ids[$0]}) else{return nil}
            let rotation=normalize(orientations[index]-orientations[parent])
            let minimum=Double(joint.attributes["minRotation"] ?? "0") ?? 0
            let maximum=Double(joint.attributes["maxRotation"] ?? "0") ?? 0
            if rotation>maximum+1e-4{return maximum}
            if rotation<minimum-1e-4{return minimum}
            return nil
        }
        var previous=hypot(points[effector].x-x,points[effector].y-y)
        // The original stops when improvement falls below .05 scene units. The bound
        // protects imported malformed/pathological geometry from blocking the UI thread.
        for _ in 0..<256 {
            points[effector].x=x;points[effector].y=y
            orientations[effector]=angle(bones[0])
            for bone in bones {
                orientations[bone.start]=angle(bone)
                let direction:Double
                if let bound=violation(bone.end){direction=orientations[bone.end]-bound}
                else {direction=hypot(points[bone.end].x-points[bone.start].x,points[bone.end].y-points[bone.start].y)>1e-9 ? angle(bone):bone.angle}
                points[bone.start].x=points[bone.end].x-cos(direction)*bone.length
                points[bone.start].y=points[bone.end].y-sin(direction)*bone.length
                orientations[bone.start]=angle(bone)
            }
            points[root].x=original[root].x;points[root].y=original[root].y
            for bone in bones.reversed() {
                orientations[bone.start]=angle(bone)
                var direction=angle(bone)
                if let bound=violation(bone.start),let parent=original[bone.start].parent.flatMap({ids[$0]}) {direction=orientations[parent]+bound}
                else if hypot(points[bone.end].x-points[bone.start].x,points[bone.end].y-points[bone.start].y)<=1e-9 {direction=bone.angle}
                points[bone.end].x=points[bone.start].x+cos(direction)*bone.length
                points[bone.end].y=points[bone.start].y+sin(direction)*bone.length
                orientations[bone.start]=angle(bone)
            }
            let distance=hypot(points[effector].x-x,points[effector].y-y)
            if previous-distance<0.05{break}
            previous=distance
        }
        for bone in bones {
            let rotation=angle(bone)-bone.angle,c=cos(rotation),s=sin(rotation)
            for i in bone.staticDescendants {
                let dx=original[i].x-original[bone.end].x,dy=original[i].y-original[bone.end].y
                points[i].x=points[bone.end].x+c*dx-s*dy
                points[i].y=points[bone.end].y+s*dx+c*dy
            }
        }
        guard points.allSatisfy({$0.x.isFinite && $0.y.isFinite}) else{throw PoseError.incompatibleTopology}
        unit.joints=points
        return abs(points[effector].x-x)<1 && abs(points[effector].y-y)<1
    }
    private static func stops(_ point:Joint)->Bool{point.attributes["base"]=="true" || point.attributes["fixed"]=="true" || point.attributes["kinstop"]=="true"}
    private static func normalize(_ angle:Double)->Double {
        var value=angle.truncatingRemainder(dividingBy:2 * .pi)
        if value < -.pi {value+=2 * .pi};if value >= .pi {value-=2 * .pi}
        return value
    }
}
