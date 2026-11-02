import UIKit
import ZIPFoundation

struct ArtworkDefinition: Decodable {
    var name: String
    var points: [[String:String]]
    var parts: [[String:String]]
    var thumbnail: String?
    var defaultScale: Double?
    var titles: [String:String]?
    var displayTitle:String {let language=Locale.preferredLanguages.first?.components(separatedBy:"-").first ?? "en";return titles?[language] ?? titles?["en"] ?? name}
    func unit(at location: CGPoint) -> SceneUnit {
        let scale=defaultScale ?? 1
        let base=points.first(where:{$0["base"]=="true"}) ?? [:]
        let baseX=Double(base["x"] ?? "0") ?? 0,baseY=Double(base["y"] ?? "0") ?? 0
        let joints = points.compactMap { p -> Joint? in
            guard let id = Int(p["id"] ?? ""), let x = Double(p["x"] ?? ""), let y = Double(p["y"] ?? "") else { return nil }
            return Joint(id: id,x: location.x+(x-baseX)*scale,y: location.y+(y-baseY)*scale,parent:p["par"].flatMap(Int.init),attributes:p)
        }
        return SceneUnit(name:name,joints:joints,attributes:["scale":String(scale),"alpha":"1","flipped":"false","state":"0"])
    }
}

final class Workspace {
    var document = SceneDocument(width:960,height:540,interframes:4,frames:[SceneFrame(id:0,units:[],attributes:[:])],attributes:[:])
    var index = 0
    var selected: Int?
    var history: [SceneDocument] = []
    var future: [SceneDocument] = []
    var catalog = (try? JSONDecoder().decode([ArtworkDefinition].self,from:Data(contentsOf:Bundle.main.resourceURL!.appendingPathComponent("Content/catalog.json")))) ?? []
    var onChange: (() -> Void)?
    let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    init() {
        let url=directory.appendingPathComponent("Autosave.animation.json")
        if let bytes=try? Data(contentsOf:url),let saved=try? JSONDecoder().decode(SceneDocument.self,from:bytes),!saved.frames.isEmpty,saved.width>0,saved.height>0 {document=saved}
    }
    var frame: SceneFrame { document.frames[index] }
    func checkpoint() { history.append(document); if history.count>60 { history.removeFirst() }; future=[] }
    func notify() { index=min(max(0,index),document.frames.count-1);onChange?();if let data=try? JSONEncoder().encode(document){try? data.write(to:directory.appendingPathComponent("Autosave.animation.json"),options:.atomic)} }
    func undo() { guard let old=history.popLast() else{return};future.append(document);document=old;notify() }
    func redo() { guard let next=future.popLast() else{return};history.append(document);document=next;notify() }
    func add(_ asset:ArtworkDefinition) { checkpoint();var unit=asset.unit(at:CGPoint(x:document.width/2,y:document.height/2));unit.name += "#"+UUID().uuidString;document.frames[index].units.append(unit);selected=frame.units.count-1;notify() }
    func addFrame() throws {
        var next=frame
        if index+1<document.frames.count {
            let following=document.frames[index+1]
            for i in next.units.indices {
                if let other=following.units.first(where:{$0.name==next.units[i].name}) { next.units[i]=try PoseInterpolation.between(next.units[i],other,progress:0.5) }
            }
        }
        checkpoint();next.id=(document.frames.map(\.id).max() ?? -1)+1
        document.frames.insert(next,at:index+1);index+=1;notify()
    }
    func deleteFrame() { guard document.frames.count>1 else{return};checkpoint();document.frames.remove(at:index);notify() }
    func removeObject() { guard let i=selected,frame.units.indices.contains(i) else{return};checkpoint();document.frames[index].units.remove(at:i);selected=nil;notify() }
    func flip() { guard let i=selected,frame.units.indices.contains(i) else{return};checkpoint();let base=frame.units[i].joints.first(where:{$0.attributes["base"]=="true"})?.x ?? frame.units[i].joints.first?.x ?? 0
        for j in document.frames[index].units[i].joints.indices {document.frames[index].units[i].joints[j].x=2*base-document.frames[index].units[i].joints[j].x};document.frames[index].units[i].attributes["flipped"] = frame.units[i].attributes["flipped"]=="true" ? "false":"true";notify()
    }
    func save(name:String) throws -> URL {
        let safe=name.replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:":",with:"_")
        let url=directory.appendingPathComponent(safe.isEmpty ? "Scene.animation.json":safe+".animation.json")
        try JSONEncoder().encode(document).write(to:url,options:.atomic);return url
    }
    func load(_ url:URL) throws {
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        let value:SceneDocument
        if url.pathExtension.lowercased()=="ats" {
            let archive=try Archive(url:url,accessMode:.read)
            guard let entry=archive["model.xml"],entry.uncompressedSize<=64*1024*1024 else{throw SceneReadError.invalidScene}
            var bytes=Data();_ = try archive.extract(entry){ bytes.append($0) }
            value=try SceneXMLReader.read(bytes)
        } else if url.pathExtension.lowercased()=="xml" { value=try SceneXMLReader.read(Data(contentsOf:url)) }
        else {value=try JSONDecoder().decode(SceneDocument.self,from:Data(contentsOf:url))}
        guard !value.frames.isEmpty,value.width>0,value.height>0 else {throw SceneReadError.invalidScene}
        checkpoint();document=value;index=0;selected=nil;notify()
    }
}

final class SceneCanvas: UIView {
    let workspace: Workspace
    var displayed: SceneFrame?
    var handles = true
    var onion = true
    var backgroundColorValue:UIColor {
        get {switch workspace.document.attributes["nativeBackground"] {case "black":return .black;case "green":return .green;default:return .white}}
        set {workspace.document.attributes["nativeBackground"] = newValue == .black ? "black" : newValue == .green ? "green" : "white"}
    }
    var cameraScale: CGFloat = 1
    var cameraOffset = CGPoint.zero
    private var dragged: (Int,Int)?
    private var before = CGPoint.zero
    private var captureOffset = CGPoint.zero
    init(_ workspace:Workspace) {self.workspace=workspace;super.init(frame:.zero);isOpaque=true;addGestureRecognizer(UIPanGestureRecognizer(target:self,action:#selector(pan(_:))));addGestureRecognizer(UIPinchGestureRecognizer(target:self,action:#selector(pinch(_:))))}
    required init?(coder:NSCoder){fatalError()}
    var viewport: CGRect {bounds.insetBy(dx:12,dy:12)}
    var ratio: CGFloat {min(viewport.width/workspace.document.width,viewport.height/workspace.document.height)*cameraScale}
    var origin: CGPoint {CGPoint(x:bounds.midX-workspace.document.width*ratio/2+cameraOffset.x,y:bounds.midY-workspace.document.height*ratio/2+cameraOffset.y)}
    var images:[String:UIImage]=[:]
    func image(_ path:String)->UIImage? {if let i=images[path]{return i};let i=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/"+path).path);images[path]=i;return i}
    override func draw(_ rect:CGRect) {
        guard let c=UIGraphicsGetCurrentContext() else{return};UIColor(white:0.17,alpha:1).setFill();c.fill(bounds)
        c.saveGState();c.translateBy(x:origin.x,y:origin.y);c.scaleBy(x:ratio,y:ratio)
        backgroundColorValue.setFill();c.fill(CGRect(x:0,y:0,width:workspace.document.width,height:workspace.document.height));c.clip(to:CGRect(x:0,y:0,width:workspace.document.width,height:workspace.document.height))
        if onion && displayed==nil && workspace.index>0 {c.saveGState();c.setAlpha(0.18);paint(workspace.document.frames[workspace.index-1],in:c,showHandles:false);c.restoreGState()}
        paint(displayed ?? workspace.frame,in:c,showHandles:handles && displayed==nil);c.restoreGState()
    }
    func paint(_ frame:SceneFrame,in c:CGContext,showHandles:Bool) {
        for (i,unit) in frame.units.enumerated() {
            let baseName=unit.name.components(separatedBy:"#")[0]
            let joints=Dictionary(unit.joints.map{($0.id,$0)},uniquingKeysWith:{$1})
            let definition=workspace.catalog.first(where:{$0.name==baseName})
            if let definition {
                let scale=Double(unit.attributes["scale"] ?? "1") ?? 1
                let flipped=unit.attributes["flipped"]=="true"
                let state=Int(unit.attributes["state"] ?? "0") ?? 0
                let grouped=Dictionary(grouping:definition.parts,by:{($0["start"] ?? "")+":"+($0["end"] ?? "")})
                let selectedParts=grouped.values.compactMap { candidates -> [String:String]? in
                    let matching=candidates.filter{($0["flipped"]=="true")==flipped}
                    let variants=matching.isEmpty ? candidates.filter{$0["flipped"] != "true"}:matching
                    return variants.first{(Int($0["state"] ?? "0") ?? 0)==state} ?? variants.first{(Int($0["state"] ?? "0") ?? 0)==0}
                }
                for part in selectedParts.sorted(by:{(Int($0["weight"] ?? "0") ?? 0)<(Int($1["weight"] ?? "0") ?? 0)}) {
                    guard let start=Int(part["start"] ?? ""),let end=Int(part["end"] ?? ""),let a=joints[start],let b=joints[end],let imagePath=part["image"],let bitmap=image(imagePath) else{continue}
                    c.saveGState();c.setAlpha(Double(unit.attributes["alpha"] ?? "1") ?? 1);c.translateBy(x:a.x,y:a.y);c.rotate(by:atan2(b.y-a.y,b.x-a.x));c.scaleBy(x:scale,y:flipped && part["flipped"] != "true" ? -scale:scale)
                    bitmap.draw(in:CGRect(x:Double(part["x_offset"] ?? "0") ?? 0,y:Double(part["y_offset"] ?? "0") ?? 0,width:bitmap.size.width,height:bitmap.size.height));c.restoreGState()
                }
            } else {
                // Unsupported artwork is visibly marked; never pretend it rendered correctly.
                c.setStrokeColor(UIColor.systemRed.cgColor);c.setLineWidth(2)
                for joint in unit.joints {if let p=joint.parent,let parent=joints[p]{c.move(to:CGPoint(x:parent.x,y:parent.y));c.addLine(to:CGPoint(x:joint.x,y:joint.y));c.strokePath()}}
            }
            if showHandles && workspace.selected==i {for joint in unit.joints {let size=8/ratio;c.setFillColor(UIColor(red:1,green:0.5,blue:0,alpha:1).cgColor);c.fillEllipse(in:CGRect(x:joint.x-size/2,y:joint.y-size/2,width:size,height:size))}}
        }
    }
    @objc func pinch(_ gesture:UIPinchGestureRecognizer){cameraScale=min(4,max(0.25,cameraScale*gesture.scale));gesture.scale=1;setNeedsDisplay()}
    @objc func pan(_ gesture:UIPanGestureRecognizer){
        let screen=gesture.location(in:self);let p=CGPoint(x:(screen.x-origin.x)/ratio,y:(screen.y-origin.y)/ratio)
        if gesture.state == .began {
            var distance=30/ratio
            for (i,unit) in workspace.frame.units.enumerated(){for (j,joint) in unit.joints.enumerated(){let d=hypot(joint.x-p.x,joint.y-p.y);if d<distance && (joint.attributes["fixed"] != "true" || joint.attributes["base"]=="true"){distance=d;dragged=(i,j)}}}
            before=p;if let target=dragged{let captured=workspace.frame.units[target.0].joints[target.1];captureOffset=CGPoint(x:p.x-captured.x,y:p.y-captured.y);workspace.checkpoint();workspace.selected=target.0}
        } else if gesture.state == .changed {
            if let (i,j)=dragged {
                let id=workspace.frame.units[i].joints[j].id
                try? JointManipulation.move(&workspace.document.frames[workspace.index].units[i],jointID:id,x:p.x-captureOffset.x,y:p.y-captureOffset.y)
            } else {let d=gesture.translation(in:self);cameraOffset.x+=d.x;cameraOffset.y+=d.y;gesture.setTranslation(.zero,in:self)}
            before=p;setNeedsDisplay()
        } else {dragged=nil;workspace.notify()}
    }
    func snapshot(size:CGSize)->UIImage {let format=UIGraphicsImageRendererFormat();format.scale=1;return UIGraphicsImageRenderer(size:size,format:format).image{context in
        context.cgContext.scaleBy(x:size.width/workspace.document.width,y:size.height/workspace.document.height);backgroundColorValue.setFill();context.fill(CGRect(origin:.zero,size:CGSize(width:workspace.document.width,height:workspace.document.height)));paint(displayed ?? workspace.frame,in:context.cgContext,showHandles:false)
    }}
}
