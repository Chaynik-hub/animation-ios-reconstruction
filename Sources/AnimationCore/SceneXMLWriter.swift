import Foundation

public enum SceneXMLWriter {
    private static func escape(_ value:String)->String {
        value.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"\"",with:"&quot;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;")
    }
    private static func tag(_ name:String,_ attributes:[String:String],empty:Bool=false)->String {
        "<"+name+attributes.keys.sorted().map{" "+$0+"=\""+escape(attributes[$0] ?? "")+"\""}.joined()+(empty ? "/>":">")
    }
    public static func write(_ scene:SceneDocument)->Data {
        var root=scene.attributes.filter{!$0.key.hasPrefix("native")}
        root["w"]=String(scene.width);root["h"]=String(scene.height);root["interframes"]=String(scene.interframes)
        if root["version_code"]==nil {root["version_code"]="127"}
        var xml="<?xml version=\"1.0\" encoding=\"UTF-8\"?>"+tag("scene",root)
        for frame in scene.frames {
            var attributes=frame.attributes;attributes["id"]=String(frame.id)
            xml+=tag("frame",attributes)
            for unit in frame.units {
                var attributes=unit.attributes;attributes["name"]=unit.name
                xml+=tag("unit",attributes)
                for joint in unit.joints {
                    var attributes=joint.attributes;attributes["id"]=String(joint.id);attributes["x"]=String(joint.x);attributes["y"]=String(joint.y)
                    if let parent=joint.parent {attributes["par"]=String(parent)}else{attributes.removeValue(forKey:"par")}
                    xml+=tag("point",attributes,empty:true)
                }
                xml+="</unit>"
            }
            xml+="</frame>"
        }
        return Data((xml+"</scene>").utf8)
    }
}
