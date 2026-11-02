import Foundation

/// PointManipulator.simpleMove/moveUnit, from retained APK evidence.
/// Kinematic effectors use the original FABRIK route; stretch mode remains separate.
public enum JointManipulation {
    public static func move(_ unit: inout SceneUnit, jointID: Int, x: Double, y: Double, stretch:Bool=false) throws {
        guard let index=unit.joints.firstIndex(where:{$0.id==jointID}) else {throw PoseError.incompatibleTopology}
        let point=unit.joints[index]
        if point.attributes["base"]=="true" {
            let dx=x-point.x,dy=y-point.y
            for i in unit.joints.indices {unit.joints[i].x+=dx;unit.joints[i].y+=dy}
            return
        }
        guard point.attributes["fixed"] != "true", let parentID=point.parent,
              let parent=unit.joints.first(where:{$0.id==parentID}) else{return}
        if point.attributes["kinstart"]=="true" {
            try InverseKinematics.solve(&unit,jointID:jointID,x:x,y:y)
            return
        }
        var affected=Set([jointID]),changed=true
        while changed {
            changed=false
            for point in unit.joints {if let id=point.parent,affected.contains(id),affected.insert(point.id).inserted{changed=true}}
        }
        if stretch,point.attributes["stretchable"]=="true" {
            let dx=x-point.x,dy=y-point.y
            for i in unit.joints.indices where affected.contains(unit.joints[i].id){unit.joints[i].x+=dx;unit.joints[i].y+=dy}
            return
        }
        if abs(parent.x-x)<1 || abs(parent.y-y)<1{return}
        let rotation=atan2(y-parent.y,x-parent.x)-atan2(point.y-parent.y,point.x-parent.x)
        let cosine=cos(rotation),sine=sin(rotation)
        for i in unit.joints.indices where affected.contains(unit.joints[i].id) {
            let dx=unit.joints[i].x-parent.x,dy=unit.joints[i].y-parent.y
            unit.joints[i].x=parent.x+cosine*dx-sine*dy
            unit.joints[i].y=parent.y+sine*dx+cosine*dy
        }
    }
}
