import Foundation

/// NlerpInterpolator.interpolate/exclude/adjustSlavesPositions. Interpolate all
/// compatible poses first, then reconcile attachments in master-before-slave order.
public enum FrameInterpolation {
    public static func between(_ first:SceneFrame,_ second:SceneFrame,progress:Double)throws->SceneFrame {
        let t=min(1,max(0,progress))
        if t==0{return first};if t==1{return second}
        let a=Dictionary(first.units.enumerated().map{($0.element.name,$0.offset)},uniquingKeysWith:{$1})
        let b=Dictionary(second.units.enumerated().map{($0.element.name,$0.offset)},uniquingKeysWith:{$1})
        guard a.count==first.units.count,b.count==second.units.count else{throw PoseError.incompatibleTopology}
        var excluded=Set(a.keys).symmetricDifference(Set(b.keys))
        // A missing master excludes its whole attachment assembly for inbetweens.
        for frame in [first,second] {
            var changed=true
            while changed {
                changed=false
                for unit in frame.units {
                    if let master=FrameManipulation.attachment(unit),excluded.contains(master.0),excluded.insert(unit.name).inserted{changed=true}
                }
            }
        }
        var output=first;output.units=[]
        SceneCamera(frame: first).interpolated(to: SceneCamera(frame: second), progress: t).write(to: &output)
        if ["nativeBackgroundID", "nativeBackgroundImage", "nativeBackgroundColor"].allSatisfy({ first.attributes[$0] == second.attributes[$0] }) {
            let background = SceneCamera(frame: first, background: true)
            let nextBackground = SceneCamera(frame: second, background: true)
            background.interpolated(to: nextBackground, progress: t).write(to: &output, background: true)
        }
        for unit in first.units where !excluded.contains(unit.name) {
            guard let end=b[unit.name] else{continue}
            var pose=try PoseInterpolation.between(unit,second.units[end],progress:t)
            if !sameAttachment(unit,second.units[end]),let base=pose.joints.firstIndex(where:{$0.attributes["base"]=="true"}) {
                pose.joints[base].attributes["attached"]="null&-1"
            }
            output.units.append(pose)
        }
        let indices=Dictionary(uniqueKeysWithValues:output.units.enumerated().map{($0.element.name,$0.offset)})
        var done=Set<Int>(),visiting=Set<Int>()
        func settle(_ i:Int)throws {
            if done.contains(i){return}
            guard visiting.insert(i).inserted else{throw PoseError.cyclicSkeleton}
            if let link=FrameManipulation.attachment(output.units[i]),let parent=indices[link.0] {
                try settle(parent)
                guard let anchor=output.units[parent].joints.first(where:{$0.id==link.1}),
                      let base=output.units[i].joints.first(where:{$0.attributes["base"]=="true"}) else{throw PoseError.incompatibleTopology}
                let dx=anchor.x-base.x,dy=anchor.y-base.y
                for j in output.units[i].joints.indices{output.units[i].joints[j].x+=dx;output.units[i].joints[j].y+=dy}
            }
            visiting.remove(i);done.insert(i)
        }
        for i in output.units.indices{try settle(i)}
        return output
    }
    private static func sameAttachment(_ a:SceneUnit,_ b:SceneUnit)->Bool {
        let left=FrameManipulation.attachment(a),right=FrameManipulation.attachment(b)
        switch (left,right){case (.none,.none):return true;case let (.some(l),.some(r)):return l.0==r.0 && l.1==r.1;default:return false}
    }
}
