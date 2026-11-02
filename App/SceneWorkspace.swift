import UIKit
import ZIPFoundation

struct ArtworkDefinition: Codable {
    var name: String
    var points: [[String:String]]
    var parts: [[String:String]]
    var thumbnail: String?
    var defaultScale: Double?
    var titles: [String:String]?
    var packID: String?
    var folderPath: [String]?
    var catalogOrder: Int?
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
    let bundledCatalog = (try? JSONDecoder().decode([ArtworkDefinition].self,from:Data(contentsOf:Bundle.main.resourceURL!.appendingPathComponent("Content/catalog.json")))) ?? []
    var catalog:[ArtworkDefinition]=[]
    var onChange: (() -> Void)?
    let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    init() {
        catalog=bundledCatalog
        let url=directory.appendingPathComponent("Autosave.animation.json")
        if let bytes=try? Data(contentsOf:url),let saved=try? JSONDecoder().decode(SceneDocument.self,from:bytes),!saved.frames.isEmpty,saved.width>0,saved.height>0 {document=saved;restoreArtwork()}
    }
    func artworkURL(_ path:String)->URL? {
        guard !path.hasPrefix("/"),!path.contains("\\"),!path.components(separatedBy:"/").contains("..") else{return nil}
        if path.hasPrefix("@local/"){return directory.appendingPathComponent(String(path.dropFirst(7)))}
        return Bundle.main.resourceURL?.appendingPathComponent("Content/"+path)
    }
    func restoreArtwork() {
        catalog=bundledCatalog
        guard let id=document.attributes["nativeArtworkDirectory"],UUID(uuidString:id) != nil,
              let data=try? Data(contentsOf:directory.appendingPathComponent("ImportedArtwork/"+id+"/catalog.json")),let custom=try? JSONDecoder().decode([ArtworkDefinition].self,from:data) else{return}
        let names=Set(custom.map(\.name));catalog=custom+bundledCatalog.filter{!names.contains($0.name)}
    }
    var frame: SceneFrame { document.frames[index] }
    func checkpoint() { history.append(document); if history.count>60 { history.removeFirst() }; future=[] }
    func notify() { index=min(max(0,index),document.frames.count-1);onChange?();if let data=try? JSONEncoder().encode(document){try? data.write(to:directory.appendingPathComponent("Autosave.animation.json"),options:.atomic)} }
    func undo() { guard let old=history.popLast() else{return};future.append(document);document=old;restoreArtwork();selected=nil;notify() }
    func redo() { guard let next=future.popLast() else{return};history.append(document);document=next;restoreArtwork();selected=nil;notify() }
    func add(_ asset:ArtworkDefinition) { checkpoint();var unit=asset.unit(at:CGPoint(x:document.width/2,y:document.height/2));unit.name = UnitIdentity.inserting(unit.name,in:frame);document.frames[index].units.append(unit);selected=frame.units.count-1;notify() }
    func addFrame() throws {
        var next=frame
        if index+1<document.frames.count {
            let following=document.frames[index+1]
            next=try FrameInterpolation.between(frame,following,progress:0.5)
        }
        checkpoint();next.id=(document.frames.map(\.id).max() ?? -1)+1
        document.frames.insert(next,at:index+1);index+=1;notify()
    }
    func deleteFrame() { guard document.frames.count>1 else{return};checkpoint();document.frames.remove(at:index);notify() }
    func removeObject() { guard let i=selected,frame.units.indices.contains(i) else{return};checkpoint();UnitEditing.remove(i,from:&document.frames[index]);selected=nil;notify() }
    func duplicateObject() {
        guard let i=selected,frame.units.indices.contains(i) else{return}
        let snapshot=UnitEditing.snapshot(in:frame,selected:i)
        var next=frame;let inserted=UnitEditing.paste(snapshot,into:&next)
        guard let first=inserted.first else{return}
        checkpoint();document.frames[index]=next;selected=first;notify()
    }
    func flip() { guard let i=selected,frame.units.indices.contains(i) else{return};checkpoint();try? UnitTransform.flip(&document.frames[index],unitIndex:i);notify()
    }
    func save(name:String) throws -> URL {
        let safe=name.replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:":",with:"_")
        let url=directory.appendingPathComponent(safe.isEmpty ? "Scene.animation.json":safe+".animation.json")
        try JSONEncoder().encode(document).write(to:url,options:.atomic);return url
    }
    func saveATS()throws->URL {
        let output=directory.appendingPathComponent(UUID().uuidString+".ats")
        let archive:Archive
        if let source=document.attributes["nativeSourceArchive"],!source.contains("/"),FileManager.default.fileExists(atPath:directory.appendingPathComponent(source).path) {
            try FileManager.default.copyItem(at:directory.appendingPathComponent(source),to:output)
            archive=try Archive(url:output,accessMode:.update)
            if let old=archive["model.xml"]{try archive.remove(old)}
        }else{archive=try Archive(url:output,accessMode:.create)}
        let data=SceneXMLWriter.write(document)
        try archive.addEntry(with:"model.xml",type:.file,uncompressedSize:Int64(data.count),compressionMethod:.deflate,provider:{position,size in data.subdata(in:Int(position)..<Int(position)+size)})
        return output
    }
    func load(_ url:URL) throws {
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        var value:SceneDocument
        if url.pathExtension.lowercased()=="ats" {
            let archive=try Archive(url:url,accessMode:.read)
            guard let entry=archive["model.xml"],entry.uncompressedSize<=64*1024*1024 else{throw SceneReadError.invalidScene}
            var bytes=Data();_ = try archive.extract(entry){ bytes.append($0) }
            value=try SceneXMLReader.read(bytes)
            let preserved=directory.appendingPathComponent(UUID().uuidString+".ats")
            try FileManager.default.copyItem(at:url,to:preserved)
            value.attributes["nativeSourceArchive"]=preserved.lastPathComponent
            if let id=try EmbeddedArtworkImporter.importFrom(archive:archive,directory:directory){value.attributes["nativeArtworkDirectory"]=id}
        } else if url.pathExtension.lowercased()=="xml" { value=try SceneXMLReader.read(Data(contentsOf:url)) }
        else {value=try JSONDecoder().decode(SceneDocument.self,from:Data(contentsOf:url))}
        guard !value.frames.isEmpty,value.width>0,value.height>0 else {throw SceneReadError.invalidScene}
        checkpoint();document=value;restoreArtwork();index=0;selected=nil;notify()
    }
}

final class SceneCanvas: UIView, UIGestureRecognizerDelegate {
    let workspace: Workspace
    var displayed: SceneFrame?
    var handles = true
    var onion = true
    var stretch = false
    var backgroundColorValue:UIColor {
        get {switch workspace.document.attributes["nativeBackground"] {case "black":return .black;case "green":return .green;default:return .white}}
        set {workspace.document.attributes["nativeBackground"] = newValue == .black ? "black" : newValue == .green ? "green" : "white"}
    }
    var cameraScale: CGFloat = 1
    var cameraOffset = CGPoint.zero
    private var dragged: (Int,Int)?
    private var before = CGPoint.zero
    private var captureOffset = CGPoint.zero
    private var transformButtons: [UIButton] = []
    private var transformStart: SceneDocument?
    private var transformFrameIndex = 0
    private var transformUnit = 0
    private var transformCenter = CGPoint.zero
    private var transformTouchOffset = CGPoint.zero
    private var transformChanged = false
    init(_ workspace: Workspace) {
        self.workspace = workspace; super.init(frame: .zero); isOpaque = true; accessibilityIdentifier = "SceneCanvas"
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:))); pan.delegate = self; addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))); pinch.delegate = self; addGestureRecognizer(pinch)
        let tap = UITapGestureRecognizer(target: self, action: #selector(selectBase(_:))); tap.delegate = self; addGestureRecognizer(tap)
        for (index, name) in ["rotator", "scaler", "mover"].enumerated() {
            let button = UIButton(type: .custom); button.tag = index; button.isHidden = true
            button.setImage(UIImage(contentsOfFile: Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/" + name + ".png").path), for: .normal)
            button.imageView?.contentMode = .scaleAspectFit; button.imageEdgeInsets = UIEdgeInsets(top: 7.5, left: 7.5, bottom: 7.5, right: 7.5)
            button.accessibilityIdentifier = ["SpriteRotate", "SpriteScale", "SpriteMove"][index]
            button.accessibilityLabel = ["Повернуть спрайт", "Масштаб спрайта", "Переместить спрайт"][index]
            button.accessibilityHint = "Потяните ручку для изменения"
            button.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(transformDrag(_:))))
            addSubview(button); transformButtons.append(button)
        }
    }
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { transformStart == nil }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let view = target { if view is UIControl { return false }; target = view.superview }
        return true
    }
    override func layoutSubviews() { super.layoutSubviews(); updateTransformControls() }
    func updateTransformControls() {
        guard handles, displayed == nil, ratio > 0, let box = selectedArtworkBounds(), let selected = workspace.selected else {
            transformButtons.forEach { $0.isHidden = true }; return
        }
        let centers = [CGPoint(x: box.minX * ratio + origin.x - 80 / 1.5, y: box.minY * ratio + origin.y - 80 / 1.5),
                       CGPoint(x: box.maxX * ratio + origin.x + 80 / 1.5, y: box.minY * ratio + origin.y - 80 / 1.5),
                       CGPoint(x: box.midX * ratio + origin.x, y: box.maxY * ratio + origin.y + 80)]
        for (button, point) in zip(transformButtons, centers) {
            // Keep the full hit target reachable when a large sprite fills the iPhone viewport.
            let center = CGPoint(x: min(max(32.5, point.x), max(32.5, bounds.width - 32.5)), y: min(max(32.5, point.y), max(32.5, bounds.height - 32.5)))
            button.frame = CGRect(x: center.x - 32.5, y: center.y - 32.5, width: 65, height: 65); button.isHidden = false
            let unit = workspace.frame.units[selected]
            if button.tag == 1 { button.accessibilityValue = unit.attributes["scale"] ?? "1" }
            if button.tag == 0, let end = unit.joints.first(where: { $0.parent != nil }), let parent = unit.joints.first(where: { $0.id == end.parent }) { button.accessibilityValue = String(atan2(end.y - parent.y, end.x - parent.x)) }
            if button.tag == 2, let base = unit.joints.first(where: { $0.attributes["base"] == "true" }) { button.accessibilityValue = "\(base.x), \(base.y)" }
        }
    }
    func selectBase(at screen: CGPoint) {
        let point = CGPoint(x: (screen.x - origin.x) / ratio, y: (screen.y - origin.y) / ratio)
        var distance = 22 / ratio
        var selected: Int?
        for i in UnitEditing.orderedIndices(in: workspace.frame).reversed() {
            guard let base = workspace.frame.units[i].joints.first(where: { $0.attributes["base"] == "true" }) else { continue }
            let value = hypot(base.x - point.x, base.y - point.y)
            if value < distance { distance = value; selected = i }
        }
        workspace.selected = selected; updateTransformControls(); setNeedsDisplay()
    }
    @objc private func selectBase(_ gesture: UITapGestureRecognizer) { selectBase(at: gesture.location(in: self)) }
    @objc private func transformDrag(_ gesture: UIPanGestureRecognizer) {
        guard let button = gesture.view as? UIButton else { return }
        if gesture.state == .began {
            guard let selected = workspace.selected, workspace.frame.units.indices.contains(selected) else { return }
            transformStart = workspace.document; transformFrameIndex = workspace.index; transformUnit = selected; transformCenter = button.center; transformChanged = false
            let down = gesture.location(in: self), translation = gesture.translation(in: self)
            transformTouchOffset = CGPoint(x: down.x - translation.x - button.center.x, y: down.y - translation.y - button.center.y)
        }
        guard let snapshot = transformStart else { return }
        guard workspace.index == transformFrameIndex else {
            if workspace.document.frames.indices.contains(transformFrameIndex), workspace.document.frames[transformFrameIndex].id == snapshot.frames[transformFrameIndex].id {
                workspace.document.frames[transformFrameIndex] = snapshot.frames[transformFrameIndex]
            }
            transformStart = nil; updateTransformControls(); workspace.notify(); return
        }
        if gesture.state == .began || gesture.state == .changed || gesture.state == .ended {
            guard let base = snapshot.frames[workspace.index].units[transformUnit].joints.first(where: { $0.attributes["base"] == "true" }) else { return }
            let location = gesture.location(in: self)
            let target = CGPoint(x: (location.x - transformTouchOffset.x - origin.x) / ratio, y: (location.y - transformTouchOffset.y - origin.y) / ratio)
            let initial = CGPoint(x: (transformCenter.x - origin.x) / ratio, y: (transformCenter.y - origin.y) / ratio)
            let operation: SpriteTransform.Operation
            if button.tag == 0 { operation = .rotate(radians: atan2(target.y - base.y, target.x - base.x) - atan2(initial.y - base.y, initial.x - base.x)) }
            else if button.tag == 1 {
                let distance = hypot(initial.x - base.x, initial.y - base.y)
                guard distance > 1e-8 else { return }
                operation = .scale(factor: max(1e-4, hypot(target.x - base.x, target.y - base.y) / distance))
            } else { operation = .move(dx: target.x - initial.x, dy: target.y - initial.y) }
            var frame = snapshot.frames[workspace.index]
            do { try SpriteTransform.apply(operation, to: &frame, unitIndex: transformUnit) } catch { return }
            workspace.document.frames[workspace.index] = frame; transformChanged = frame != snapshot.frames[workspace.index]
            updateTransformControls(); setNeedsDisplay()
        }
        if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            if gesture.state == .cancelled || gesture.state == .failed { workspace.document = snapshot }
            else if transformChanged { workspace.history.append(snapshot); if workspace.history.count > 60 { workspace.history.removeFirst() }; workspace.future = [] }
            transformStart = nil; updateTransformControls(); workspace.notify()
        }
    }

    required init?(coder:NSCoder){fatalError()}
    var viewport: CGRect {bounds.insetBy(dx:12,dy:12)}
    var ratio: CGFloat {min(viewport.width/workspace.document.width,viewport.height/workspace.document.height)*cameraScale}
    var origin: CGPoint {CGPoint(x:bounds.midX-workspace.document.width*ratio/2+cameraOffset.x,y:bounds.midY-workspace.document.height*ratio/2+cameraOffset.y)}
    var images:[String:UIImage]=[:]
    func image(_ path:String)->UIImage? {if let i=images[path]{return i};guard let url=workspace.artworkURL(path) else{return nil};let i=UIImage(contentsOfFile:url.path);images[path]=i;return i}
    override func draw(_ rect:CGRect) {
        guard let c=UIGraphicsGetCurrentContext() else{return};UIColor.original(0x3d3e4c).setFill();c.fill(bounds)
        c.saveGState();c.translateBy(x:origin.x,y:origin.y);c.scaleBy(x:ratio,y:ratio)
        backgroundColorValue.setFill();c.fill(CGRect(x:0,y:0,width:workspace.document.width,height:workspace.document.height));c.clip(to:CGRect(x:0,y:0,width:workspace.document.width,height:workspace.document.height))
        if onion && displayed==nil && workspace.index>0 {c.saveGState();paint(workspace.document.frames[workspace.index-1],in:c,showHandles:false,opacity:0.18);c.restoreGState()}
        paint(displayed ?? workspace.frame,in:c,showHandles:handles && displayed==nil);c.restoreGState()
    }
    func paint(_ frame:SceneFrame,in c:CGContext,showHandles:Bool,opacity:CGFloat=1) {
        for i in UnitEditing.orderedIndices(in:frame) {
            let unit=frame.units[i]
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
                    var longitudinal=1.0
                    if b.attributes["stretchable"]=="true",scale>0,
                       let restStart=definition.points.first(where:{$0["id"]==String(start)}),
                       let restEnd=definition.points.first(where:{$0["id"]==String(end)}),
                       let ax=Double(restStart["x"] ?? ""),let ay=Double(restStart["y"] ?? ""),let bx=Double(restEnd["x"] ?? ""),let by=Double(restEnd["y"] ?? "") {
                        let rest=hypot(bx-ax,by-ay)*scale
                        if rest>0 {longitudinal=hypot(b.x-a.x,b.y-a.y)/rest}
                    }
                    c.saveGState();c.translateBy(x:a.x,y:a.y);c.rotate(by:atan2(b.y-a.y,b.x-a.x));c.scaleBy(x:scale*longitudinal,y:flipped && part["flipped"] != "true" ? -scale:scale)
                    bitmap.draw(in:CGRect(x:Double(part["x_offset"] ?? "0") ?? 0,y:Double(part["y_offset"] ?? "0") ?? 0,width:bitmap.size.width,height:bitmap.size.height),blendMode:.normal,alpha:CGFloat(Double(unit.attributes["alpha"] ?? "1") ?? 1)*opacity);c.restoreGState()
                }
            } else {
                // Unsupported artwork is visibly marked; never pretend it rendered correctly.
                c.setStrokeColor(UIColor.systemRed.cgColor);c.setLineWidth(2)
                for joint in unit.joints {if let p=joint.parent,let parent=joints[p]{c.move(to:CGPoint(x:parent.x,y:parent.y));c.addLine(to:CGPoint(x:joint.x,y:joint.y));c.strokePath()}}
            }
            if showHandles && workspace.selected==i {
                c.saveGState();c.setAlpha(1);c.setStrokeColor(UIColor.orange.cgColor);c.setLineWidth(1/ratio)
                for joint in unit.joints {if let parentID=joint.parent,let parent=joints[parentID]{c.move(to:CGPoint(x:parent.x,y:parent.y));c.addLine(to:CGPoint(x:joint.x,y:joint.y))}}
                c.strokePath()
                for joint in unit.joints {let size=8/ratio;c.setFillColor(UIColor(red:1,green:0.5,blue:0,alpha:1).cgColor);c.fillEllipse(in:CGRect(x:joint.x-size/2,y:joint.y-size/2,width:size,height:size))}
                c.restoreGState()
            }
        }
    }
    @objc func pinch(_ gesture:UIPinchGestureRecognizer){cameraScale=min(4,max(0.25,cameraScale*gesture.scale));gesture.scale=1;updateTransformControls();setNeedsDisplay()}
    @objc func pan(_ gesture:UIPanGestureRecognizer){
        let screen=gesture.location(in:self);let p=CGPoint(x:(screen.x-origin.x)/ratio,y:(screen.y-origin.y)/ratio)
        if gesture.state == .began {
            var distance=30/ratio
            for (i,unit) in workspace.frame.units.enumerated(){for (j,joint) in unit.joints.enumerated(){let d=hypot(joint.x-p.x,joint.y-p.y);if d<distance && (joint.attributes["fixed"] != "true" || joint.attributes["base"]=="true"){distance=d;dragged=(i,j)}}}
            before=p;if let target=dragged{let captured=workspace.frame.units[target.0].joints[target.1];captureOffset=CGPoint(x:p.x-captured.x,y:p.y-captured.y);workspace.checkpoint();workspace.selected=target.0}
        } else if gesture.state == .changed {
            if let (i,j)=dragged {
                let id=workspace.frame.units[i].joints[j].id
                try? FrameManipulation.move(&workspace.document.frames[workspace.index],unitIndex:i,jointID:id,x:p.x-captureOffset.x,y:p.y-captureOffset.y,stretch:stretch)
            } else {let d=gesture.translation(in:self);cameraOffset.x+=d.x;cameraOffset.y+=d.y;gesture.setTranslation(.zero,in:self)}
            before=p;updateTransformControls();setNeedsDisplay()
        } else {
            if gesture.state == .ended,let (unitIndex,_)=dragged,FrameManipulation.attachNearby(&workspace.document.frames[workspace.index],unitIndex:unitIndex,radius:25/ratio){workspace.selected=nil}
            dragged=nil;updateTransformControls();workspace.notify()
        }
    }
    func snapshot(size:CGSize)->UIImage {let format=UIGraphicsImageRendererFormat();format.scale=1;return UIGraphicsImageRenderer(size:size,format:format).image{context in
        context.cgContext.scaleBy(x:size.width/workspace.document.width,y:size.height/workspace.document.height);backgroundColorValue.setFill();context.fill(CGRect(origin:.zero,size:CGSize(width:workspace.document.width,height:workspace.document.height)));paint(displayed ?? workspace.frame,in:context.cgContext,showHandles:false)
    }}
}
