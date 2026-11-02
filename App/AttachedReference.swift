import UIKit
extension Workspace {
    func installAttachedReference() {
        guard let host=catalog.first(where:{$0.name=="newstickman:stickman"}),let item=catalog.first(where:{$0.name=="newstickman:sword"}) else{return}
        let master=host.unit(at:CGPoint(x:480,y:270))
        guard let anchor=master.joints.first(where:{$0.attributes["attachable"]=="master"}) else{return}
        var slave=item.unit(at:CGPoint(x:anchor.x,y:anchor.y))
        guard let base=slave.joints.firstIndex(where:{$0.attributes["base"]=="true"}) else{return}
        slave.joints[base].attributes["attached"]=master.name+"&"+String(anchor.id)
        document=SceneDocument(width:960,height:540,interframes:4,frames:[SceneFrame(id:0,units:[master,slave],attributes:[:])],attributes:[:]);index=0;selected=1;history=[];future=[];notify()
    }
}
