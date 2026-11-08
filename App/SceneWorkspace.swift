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
    var packCover: String? = nil
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
    var latchedUnitName: String?
    var backgroundLibraryCache: [BackgroundDefinition]?
    var history: [SceneDocument] = []
    var future: [SceneDocument] = []
    let bundledCatalog = (try? JSONDecoder().decode([ArtworkDefinition].self,from:Data(contentsOf:Bundle.main.resourceURL!.appendingPathComponent("Content/catalog.json")))) ?? []
    var catalog:[ArtworkDefinition]=[] {
        didSet { artworkByName = Dictionary(catalog.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first }) }
    }
    private(set) var artworkByName: [String: ArtworkDefinition] = [:]
    var onChange: (() -> Void)?
    var autosaveEnabled = true
    let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    init() {
        catalog=bundledCatalog+UserSpriteLibrary.definitions(in:directory)
        let url=directory.appendingPathComponent("Autosave.animation.json")
        if let bytes=try? Data(contentsOf:url),let saved=try? JSONDecoder().decode(SceneDocument.self,from:bytes),!saved.frames.isEmpty,saved.width>0,saved.height>0 {document=saved;restoreArtwork()}
    }
    func artworkURL(_ path:String)->URL? {
        guard !path.hasPrefix("/"),!path.contains("\\"),!path.components(separatedBy:"/").contains("..") else{return nil}
        if path.hasPrefix("@local/"){return directory.appendingPathComponent(String(path.dropFirst(7)))}
        return Bundle.main.resourceURL?.appendingPathComponent("Content/"+path)
    }
    func restoreArtwork() {
        catalog=bundledCatalog+UserSpriteLibrary.definitions(in:directory)
        guard let id=document.attributes["nativeArtworkDirectory"],UUID(uuidString:id) != nil,
              let data=try? Data(contentsOf:directory.appendingPathComponent("ImportedArtwork/"+id+"/catalog.json")),let custom=try? JSONDecoder().decode([ArtworkDefinition].self,from:data) else{return}
        let names=Set(custom.map(\.name));catalog=custom+catalog.filter{!names.contains($0.name)}
    }
    var frame: SceneFrame { document.frames[index] }
    func checkpoint() { history.append(document); if history.count>60 { history.removeFirst() }; future=[] }
    func notify(save: Bool = true) { index=min(max(0,index),document.frames.count-1);onChange?();if save,autosaveEnabled,let data=try? JSONEncoder().encode(document){try? data.write(to:directory.appendingPathComponent("Autosave.animation.json"),options:.atomic)} }
    func undo() { guard let old=history.popLast() else{return};future.append(document);document=old;restoreArtwork();selected=nil;latchedUnitName=nil;notify() }
    func redo() { guard let next=future.popLast() else{return};history.append(document);document=next;restoreArtwork();selected=nil;latchedUnitName=nil;notify() }
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
    func removeObject() { guard let i=selected,frame.units.indices.contains(i) else{return};checkpoint();UnitEditing.remove(i,from:&document.frames[index]);selected=nil;latchedUnitName=nil;notify() }
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
        let used=Set(document.frames.flatMap{$0.units}.map{UnitIdentity.baseName($0.name)})
        for record in UserSpriteLibrary.records(in:directory) where used.contains(record.definition.name) {
            guard let url=artworkURL("@local/"+record.archive) else{continue}
            let bytes=try Data(contentsOf:url),path="user-items/"+record.definition.name.replacingOccurrences(of:"@:",with:"")+".ati"
            if let old=archive[path]{try archive.remove(old)}
            try archive.addEntry(with:path,type:.file,uncompressedSize:Int64(bytes.count),compressionMethod:.deflate,provider:{position,size in bytes.subdata(in:Int(position)..<Int(position)+size)})
        }
        let data=SceneXMLWriter.write(document)
        try archive.addEntry(with:"model.xml",type:.file,uncompressedSize:Int64(data.count),compressionMethod:.deflate,provider:{position,size in data.subdata(in:Int(position)..<Int(position)+size)})
        return output
    }
    func load(_ url:URL) throws {
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        var value:SceneDocument
        if url.pathExtension.lowercased()=="animationproject" {
            value = try CloudProjectArchive.unpack(url, into: directory)
        } else if url.pathExtension.lowercased()=="ats" {
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
        checkpoint();document=value;restoreArtwork();index=0;selected=nil;latchedUnitName=nil;notify()
    }
}

final class SceneCanvas: UIView, UIGestureRecognizerDelegate {
    let workspace: Workspace
    var displayed: SceneFrame?
    var handles = true
    var onion = true
    var stretch = false
    private var attachmentDragUnit: Int?
    private let snapFeedback = UIImpactFeedbackGenerator(style: .light)

    private func snapAttachment(_ unit: Int) -> Bool {
        guard FrameManipulation.attachNearby(&workspace.document.frames[workspace.index], unitIndex: unit, radius: 25 / ratio)
        else { return false }
        if AnimationSettings.bool("vibroPref", fallback: true) { snapFeedback.impactOccurred() }
        return true
    }

    private func paintAttachmentHint(in context: CGContext) {
        guard ratio > 0, let unit = attachmentDragUnit,
              let base = FrameManipulation.attachmentBase(in: workspace.frame, unitIndex: unit) else { return }
        context.saveGState()
        defer { context.restoreGState() }
        let radius = 25 / ratio
        context.setLineWidth(2 / ratio)
        context.setFillColor(UIColor.original(0xff4141).withAlphaComponent(0.35).cgColor)
        context.fillEllipse(in: CGRect(x: base.x - radius, y: base.y - radius, width: radius * 2, height: radius * 2))
        guard let hint = FrameManipulation.attachmentHint(in: workspace.frame, unitIndex: unit, radius: radius) else { return }
        let green = UIColor.original(0x72bd00).withAlphaComponent(0.55).cgColor
        context.setFillColor(green)
        let dot = 12 / ratio
        context.fillEllipse(in: CGRect(x: hint.point.x - dot, y: hint.point.y - dot, width: 2 * dot, height: 2 * dot))
    }

    var boneMode = false {
        didSet {
            if !boneMode { boneJoint = nil }
            updateTransformControls()
            setNeedsDisplay()
        }
    }
    var boneJoint: Int?
    var boneButtons: [UIButton] = []
    weak var boneGesture: UIPanGestureRecognizer?
    var boneDrag: (frame: Int, unit: Int, joint: Int, length: Double, axis: CGPoint, ratio: CGFloat)?

    var backgroundColorValue:UIColor {
        get {switch workspace.document.attributes["nativeBackground"] {case "black":return .black;case "green":return .green;default:return .white}}
        set {workspace.document.attributes["nativeBackground"] = newValue == .black ? "black" : newValue == .green ? "green" : "white"}
    }
    private var cameraGestures = Set<ObjectIdentifier>()
    var cameraEditing = false {
        didSet { if oldValue != cameraEditing { updateTransformControls(); setNeedsDisplay() } }
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
        NotificationCenter.default.addObserver(self,selector:#selector(settingsChanged),name:.animationSettingsChanged,object:nil)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:))); pan.delegate = self; addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))); pinch.delegate = self; addGestureRecognizer(pinch)
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(rotateCamera(_:))); rotate.delegate = self; addGestureRecognizer(rotate)
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
    @objc private func settingsChanged() {setNeedsDisplay()}
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        transformStart == nil && (cameraEditing || !(gestureRecognizer is UIRotationGestureRecognizer))
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        cameraEditing && gestureRecognizer.view === self && other.view === self
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if cameraEditing && gestureRecognizer is UITapGestureRecognizer { return false }
        var target = touch.view
        while let view = target { if view is UIControl { return false }; target = view.superview }
        return true
    }
    override func layoutSubviews() { super.layoutSubviews(); updateTransformControls() }
    func updateTransformControls() {
        updateBoneButtons()
        if boneMode {
            transformButtons.forEach { $0.isHidden = true }
            return
        }
        guard handles, !cameraEditing, displayed == nil, ratio > 0, let box = selectedArtworkBounds(), let selected = workspace.selected else {
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
        if boneMode { selectBone(at: screen); return }
        let point = CGPoint(x: (screen.x - origin.x) / ratio, y: (screen.y - origin.y) / ratio)
        var distance = 22 / ratio
        var selected: Int?
    var latchedUnitName: String?
    var backgroundLibraryCache: [BackgroundDefinition]?
        for i in UnitEditing.orderedIndices(in: workspace.frame).reversed() where workspace.canInteract(with:i) {
            guard let base = workspace.frame.units[i].joints.first(where: { $0.attributes["base"] == "true" }) else { continue }
            let value = hypot(base.x - point.x, base.y - point.y)
            if value < distance { distance = value; selected = i }
        }
        workspace.selected = selected; updateTransformControls(); setNeedsDisplay(); workspace.onChange?()
    }
    @objc private func selectBase(_ gesture: UITapGestureRecognizer) { selectBase(at: gesture.location(in: self)) }
    @objc private func transformDrag(_ gesture: UIPanGestureRecognizer) {
        guard let button = gesture.view as? UIButton else { return }
        if gesture.state == .began {
            guard let selected = workspace.selected, workspace.frame.units.indices.contains(selected) else { return }
            attachmentDragUnit = button.tag == 2 ? selected : nil
            transformStart = workspace.document; transformFrameIndex = workspace.index; transformUnit = selected; transformCenter = button.center; transformChanged = false
            let down = gesture.location(in: self), translation = gesture.translation(in: self)
            transformTouchOffset = CGPoint(x: down.x - translation.x - button.center.x, y: down.y - translation.y - button.center.y)
        }
        guard let snapshot = transformStart else { return }
        guard workspace.index == transformFrameIndex else {
            if workspace.document.frames.indices.contains(transformFrameIndex), workspace.document.frames[transformFrameIndex].id == snapshot.frames[transformFrameIndex].id {
                workspace.document.frames[transformFrameIndex] = snapshot.frames[transformFrameIndex]
            }
            attachmentDragUnit = nil
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
            attachmentDragUnit = nil
            if gesture.state == .cancelled || gesture.state == .failed { workspace.document = snapshot }
            else if transformChanged {
                if button.tag == 2 { _ = snapAttachment(transformUnit) }
                workspace.history.append(snapshot); if workspace.history.count > 60 { workspace.history.removeFirst() }; workspace.future = [] }
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
        let editing = handles && displayed == nil
        if !editing || cameraEditing { applySceneCamera(displayed ?? workspace.frame, in: c) }
        if !editing || AnimationSettings.bool("showbgPref", fallback:true) { paintBackground(displayed ?? workspace.frame,in:c) }
        if editing && !cameraEditing && AnimationSettings.bool("showGridPref") {
            c.saveGState();c.setStrokeColor(UIColor.gray.withAlphaComponent(0.3).cgColor);c.setLineWidth(1/ratio)
            for x in stride(from:0.0,through:workspace.document.width,by:50) {c.move(to:CGPoint(x:x,y:0));c.addLine(to:CGPoint(x:x,y:workspace.document.height))}
            for y in stride(from:0.0,through:workspace.document.height,by:50) {c.move(to:CGPoint(x:0,y:y));c.addLine(to:CGPoint(x:workspace.document.width,y:y))}
            c.strokePath();c.restoreGState()
        }
        if onion && editing && !cameraEditing && workspace.index>0 && AnimationSettings.onionMode != 0 {
            for distance in (1...min(workspace.index,AnimationSettings.onionCount)).reversed() {
                let previous = workspace.document.frames[workspace.index-distance]
                if AnimationSettings.onionMode == 2 { c.saveGState();c.setAlpha(0.25/CGFloat(distance));paintSkeleton(previous,in:c,points:false);c.restoreGState() }
                else if AnimationSettings.onionMode == 3 {
                    c.saveGState()
                    c.beginTransparencyLayer(auxiliaryInfo: nil)
                    var silhouette = previous
                    for index in silhouette.units.indices { silhouette.units[index].attributes["alpha"] = "1" }
                    paint(silhouette, in: c, showHandles: false)
                    c.setBlendMode(.sourceIn)
                    AnimationSettings.onionColor.setFill()
                    c.fill(CGRect(x: 0, y: 0, width: workspace.document.width, height: workspace.document.height))
                    c.endTransparencyLayer()
                    c.restoreGState()
                } else {paint(previous,in:c,showHandles:false,opacity:0.18/CGFloat(distance))}
            }
        }
        paint(displayed ?? workspace.frame,in:c,showHandles:false)
        if editing && !cameraEditing {
            paintSkeleton(workspace.frame,in:c,points:true)
            paintSelectedBone(in: c)
            paintAttachmentHint(in: c)
        }
        if editing && !cameraEditing && AnimationSettings.bool("showCamera",fallback:true) {c.setStrokeColor(UIColor.darkGray.cgColor);c.setLineWidth(2/ratio);c.stroke(CGRect(x:0,y:0,width:workspace.document.width,height:workspace.document.height))}
        c.restoreGState()
        if cameraEditing {
            c.setStrokeColor(UIColor.original(0x00c0d8).cgColor)
            c.setLineWidth(2)
            c.stroke(CGRect(origin: origin, size: CGSize(
                width: workspace.document.width * ratio,
                height: workspace.document.height * ratio
            )))
        }
    }
    func paint(_ frame:SceneFrame,in c:CGContext,showHandles:Bool,opacity:CGFloat=1) {
        for i in UnitEditing.orderedIndices(in:frame) {
            let unit=frame.units[i]
            let baseName=unit.name.components(separatedBy:"#")[0]
            let joints=Dictionary(unit.joints.map{($0.id,$0)},uniquingKeysWith:{$1})
            let definition=workspace.artworkByName[baseName]
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
                    if (b.attributes["stretchable"] == "true" || (b.parent == a.id && b.attributes["nativeAxisStretch"] == "true") || (a.parent == b.id && a.attributes["nativeAxisStretch"] == "true")), scale > 0,
                       let restStart=definition.points.first(where:{$0["id"]==String(start)}),
                       let restEnd=definition.points.first(where:{$0["id"]==String(end)}),
                       let ax=Double(restStart["x"] ?? ""),let ay=Double(restStart["y"] ?? ""),let bx=Double(restEnd["x"] ?? ""),let by=Double(restEnd["y"] ?? "") {
                        let rest=hypot(bx-ax,by-ay)*scale
                        if rest>0 {longitudinal=hypot(b.x-a.x,b.y-a.y)/rest}
                    }
                    var anchorX = a.x, anchorY = a.y
                    if b.parent == a.id {
                        longitudinal *= FrameManipulation.boneLengthFactor(b)
                    } else if a.parent == b.id {
                        let factor = FrameManipulation.boneLengthFactor(a)
                        longitudinal *= factor
                        anchorX = b.x + (a.x - b.x) * factor
                        anchorY = b.y + (a.y - b.y) * factor
                    }
                    c.saveGState()
                    c.translateBy(x: anchorX, y: anchorY)
                    c.rotate(by: atan2(b.y - a.y, b.x - a.x))
                    let xOffset = Double(part["x_offset"] ?? "0") ?? 0
                    let yOffset = Double(part["y_offset"] ?? "0") ?? 0
                    let axialScale = scale * longitudinal
                    if axialScale > 0 {
                        let upper = (xOffset + Double(bitmap.size.width)) * axialScale
                        let lower = xOffset * axialScale
                        let halfHeight = (abs(yOffset) + Double(bitmap.size.height) + 1) * abs(scale)
                        if b.parent == a.id && b.attributes["nativeAxisStretch"] == "true" {
                            c.clip(to: CGRect(x: 0, y: -halfHeight, width: max(0, upper), height: 2 * halfHeight))
                        } else if a.parent == b.id && a.attributes["nativeAxisStretch"] == "true" {
                            let joint = hypot(b.x - a.x, b.y - a.y)
                            c.clip(to: CGRect(x: lower, y: -halfHeight, width: max(0, joint - lower), height: 2 * halfHeight))
                        }
                    }
                    c.scaleBy(x:scale*longitudinal,y:flipped && part["flipped"] != "true" ? -scale:scale)
                    bitmap.draw(in:CGRect(x:Double(part["x_offset"] ?? "0") ?? 0,y:Double(part["y_offset"] ?? "0") ?? 0,width:bitmap.size.width,height:bitmap.size.height),blendMode:.normal,alpha:CGFloat(Double(unit.attributes["alpha"] ?? "1") ?? 1)*opacity);c.restoreGState()
                }
            }
        }
        if showHandles {paintSkeleton(frame,in:c,points:true)}
    }
    private func paintSkeleton(_ frame:SceneFrame,in c:CGContext,points:Bool) {
        c.saveGState();defer{c.restoreGState()}
        c.setStrokeColor(AnimationSettings.skeletonColor.cgColor);c.setFillColor(AnimationSettings.skeletonColor.cgColor);c.setLineWidth(1.5/ratio)
        for unit in frame.units {
            let joints=Dictionary(unit.joints.map{($0.id,$0)},uniquingKeysWith:{$1})
            for joint in unit.joints {if let parentID=joint.parent,let parent=joints[parentID]{c.move(to:CGPoint(x:parent.x,y:parent.y));c.addLine(to:CGPoint(x:joint.x,y:joint.y))}}
            c.strokePath()
            if points {for joint in unit.joints where joint.attributes["fixed"] != "true" || joint.attributes["base"] == "true" {let size=8/ratio;c.fillEllipse(in:CGRect(x:joint.x-size/2,y:joint.y-size/2,width:size,height:size))}}
        }
    }
    private func applySceneCamera(_ frame: SceneFrame, in context: CGContext) {
        let camera = SceneCamera(frame: frame)
        let center = CGPoint(x: workspace.document.width / 2, y: workspace.document.height / 2)
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: camera.rotation)
        context.scaleBy(x: camera.zoom, y: camera.zoom)
        context.translateBy(x: -center.x - camera.x, y: -center.y - camera.y)
    }

    func resetSceneCamera() {
        workspace.checkpoint()
        SceneCamera().write(to: &workspace.document.frames[workspace.index])
        workspace.notify()
        setNeedsDisplay()
    }

    private func trackCameraGesture(_ gesture: UIGestureRecognizer) {
        let id = ObjectIdentifier(gesture)
        switch gesture.state {
        case .began:
            if cameraGestures.isEmpty { workspace.checkpoint() }
            cameraGestures.insert(id)
        case .ended, .cancelled, .failed:
            cameraGestures.remove(id)
        default: break
        }
    }

    @objc private func rotateCamera(_ gesture: UIRotationGestureRecognizer) {
        guard cameraEditing else { return }
        trackCameraGesture(gesture)
        var camera = SceneCamera(frame: workspace.frame)
        switch gesture.state {
        case .changed:
            camera.rotation += gesture.rotation
            gesture.rotation = 0
        case .ended, .cancelled:
            let step = Double.pi / 36
            let snapped = (camera.rotation / step).rounded() * step
            camera.rotation = atan2(sin(snapped), cos(snapped))
        default: return
        }
        camera.write(to: &workspace.document.frames[workspace.index])
        setNeedsDisplay()
    }

    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
        if cameraEditing {
            trackCameraGesture(gesture)
            guard gesture.state == .changed else { return }
            var camera = SceneCamera(frame: workspace.frame)
            camera.zoom = min(8, max(0.25, camera.zoom * gesture.scale))
            camera.write(to: &workspace.document.frames[workspace.index])
        } else {
            cameraScale = min(4, max(0.25, cameraScale * gesture.scale))
        }
        gesture.scale = 1
        updateTransformControls()
        setNeedsDisplay()
    }

    @objc func pan(_ gesture: UIPanGestureRecognizer){
        if cameraEditing {
            trackCameraGesture(gesture)
            if gesture.state == .changed {
                var camera = SceneCamera(frame: workspace.frame)
                let delta = gesture.translation(in: self)
                let angle = -camera.rotation
                let scale = Double(ratio) * camera.zoom
                guard scale > 0 else { return }
                let dx = Double(delta.x), dy = Double(delta.y)
                let cosine = cos(angle), sine = sin(angle)
                camera.x -= (dx * cosine - dy * sine) / scale
                camera.y -= (dx * sine + dy * cosine) / scale
                camera.write(to: &workspace.document.frames[workspace.index])
                gesture.setTranslation(.zero, in: self)
                setNeedsDisplay()
            }
            return
        }
        let screen=gesture.location(in:self);let p=CGPoint(x:(screen.x-origin.x)/ratio,y:(screen.y-origin.y)/ratio)
        if gesture.state == .began {
            var distance=30/ratio
            for (i, unit) in workspace.frame.units.enumerated() where workspace.canInteract(with: i) {
                let attachment = FrameManipulation.attachment(unit)
                let attached = attachment.map { link in
                    workspace.frame.units.contains { master in
                        master.name == link.0 && master.joints.contains { $0.id == link.1 }
                    }
                } ?? false
                for (j, joint) in unit.joints.enumerated() {
                    let base = joint.attributes["base"] == "true"
                    guard !(base && attached), joint.attributes["fixed"] != "true" || base else { continue }
                    let d = hypot(joint.x - p.x, joint.y - p.y)
                    if d < distance { distance = d; dragged = (i, j) }
                }
            }
            before=p;if let target=dragged{let captured=workspace.frame.units[target.0].joints[target.1];captureOffset=CGPoint(x:p.x-captured.x,y:p.y-captured.y);attachmentDragUnit = captured.attributes["base"] == "true" ? target.0 : nil;workspace.checkpoint();workspace.selected=target.0}
        } else if gesture.state == .changed {
            if let (i,j)=dragged {
                let id=workspace.frame.units[i].joints[j].id
                try? FrameManipulation.move(&workspace.document.frames[workspace.index],unitIndex:i,jointID:id,x:p.x-captureOffset.x,y:p.y-captureOffset.y,stretch:stretch)
            } else {let d=gesture.translation(in:self);cameraOffset.x+=d.x;cameraOffset.y+=d.y;gesture.setTranslation(.zero,in:self)}
            before=p;updateTransformControls();setNeedsDisplay()
        } else {
            if gesture.state == .ended, let unitIndex = attachmentDragUnit, snapAttachment(unitIndex) { workspace.selected = nil }
            attachmentDragUnit = nil
            dragged=nil;updateTransformControls();workspace.notify()
        }
    }
    func snapshot(size:CGSize)->UIImage {let format=UIGraphicsImageRendererFormat();format.scale=1;return UIGraphicsImageRenderer(size:size,format:format).image{context in
        context.cgContext.scaleBy(x:size.width/workspace.document.width,y:size.height/workspace.document.height);backgroundColorValue.setFill();context.fill(CGRect(origin:.zero,size:CGSize(width:workspace.document.width,height:workspace.document.height)));applySceneCamera(displayed ?? workspace.frame, in: context.cgContext);paintBackground(displayed ?? workspace.frame,in:context.cgContext);paint(displayed ?? workspace.frame,in:context.cgContext,showHandles:false)
    }}
}
