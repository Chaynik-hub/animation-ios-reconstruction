import Foundation

public enum UnitTransform {
    /// Unit.flip mirrors all attached slaves around the selected unit's base,
    /// rather than mirroring only its skeleton and leaving held objects behind.
    public static func flip(_ frame:inout SceneFrame,unitIndex:Int)throws {
        guard frame.units.indices.contains(unitIndex),let base=frame.units[unitIndex].joints.first(where:{$0.attributes["base"]=="true"}) else{throw PoseError.incompatibleTopology}
        var affected=Set([unitIndex]),pending=[unitIndex]
        while let master=pending.popLast() {
            for i in frame.units.indices where !affected.contains(i) {
                if let link=FrameManipulation.attachment(frame.units[i]),link.0==frame.units[master].name {affected.insert(i);pending.append(i)}
            }
        }
        for i in affected {
            for j in frame.units[i].joints.indices{frame.units[i].joints[j].x=2*base.x-frame.units[i].joints[j].x}
            frame.units[i].attributes["flipped"]=frame.units[i].attributes["flipped"]=="true" ? "false":"true"
        }
    }
}
