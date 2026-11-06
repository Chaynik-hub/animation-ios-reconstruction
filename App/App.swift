import UIKit
import UniformTypeIdentifiers
import ImageIO
import AVFoundation
import CoreText

@main final class AppDelegate:UIResponder,UIApplicationDelegate {
    func application(_ application:UIApplication,didFinishLaunchingWithOptions options:[UIApplication.LaunchOptionsKey:Any]?)->Bool {
        let fonts=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Fonts")
        for file in (try? FileManager.default.contentsOfDirectory(at:fonts,includingPropertiesForKeys:nil)) ?? [] where ["ttf","otf"].contains(file.pathExtension.lowercased()) {CTFontManagerRegisterFontsForURL(file as CFURL,.process,nil)}
        return true
    }
    func application(_ application:UIApplication,configurationForConnecting session:UISceneSession,options:UIScene.ConnectionOptions)->UISceneConfiguration {
        let configuration=UISceneConfiguration(name:"Default",sessionRole:session.role);configuration.delegateClass=SceneDelegate.self;return configuration
    }
}
final class SceneDelegate:UIResponder,UIWindowSceneDelegate {
    var window:UIWindow?
    func scene(_ scene:UIScene,willConnectTo session:UISceneSession,options:UIScene.ConnectionOptions) {
        guard let windowScene=scene as? UIWindowScene else{return}
        let window=UIWindow(windowScene:windowScene);let arguments = ProcessInfo.processInfo.arguments
        window.rootViewController = arguments.contains(where: { $0.hasPrefix("--reference-") || $0 == "--ui-capture" }) ? EditorController() : LandingController()
        self.window=window;window.makeKeyAndVisible()
        if !windowScene.interfaceOrientation.isLandscape {windowScene.requestGeometryUpdate(.iOS(interfaceOrientations:.landscapeRight))}
    }
}

final class EditorController:UIViewController,UIDocumentPickerDelegate {
    let workspace=Workspace()
    lazy var canvas=SceneCanvas(workspace)
    let sidebar=UIStackView(),sidebarScroll=UIScrollView(),navigation=UIStackView(),frameLabel=UILabel(),shift=UIButton(type:.custom)
    let frameNavigator=FrameNavigator()
    var displayLink:CADisplayLink?
    var playbackStart:CFTimeInterval=0
    var startFrame=0
    var titleOfScene="Animation"
    override var prefersStatusBarHidden:Bool{AnimationSettings.bool("fullScreen",fallback:true)}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor=UIColor(red:36/255,green:37/255,blue:48/255,alpha:1)
        canvas.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(canvas)
        for stack in [sidebar,navigation]{stack.axis = .vertical;stack.distribution = .fillEqually;stack.translatesAutoresizingMaskIntoConstraints=false}
        sidebarScroll.translatesAutoresizingMaskIntoConstraints=false;sidebarScroll.showsVerticalScrollIndicator=false;view.addSubview(sidebarScroll);sidebarScroll.addSubview(sidebar);view.addSubview(navigation)
        sidebar.distribution = .fill
        sidebar.backgroundColor=view.backgroundColor;navigation.backgroundColor=view.backgroundColor
        let entries:[(String,String,UIColor,()->Void)]=[
            ("main_btn_nav","",.white,{[weak self] in self?.menu()}),
            ("main_btn_play","ПУСК",.original(0xff9000),{[weak self] in self?.togglePlayback()}),
            ("main_btn_insert","ДОБАВИТЬ",.original(0x72bd00),{[weak self] in self?.objects()}),
            ("main_btn_props","РЕДАКТ.",.original(0x00bd78),{[weak self] in self?.objectTools()}),
            ("main_btn_frames","РЕД. КАДР",.original(0x449ec9),{[weak self] in self?.frameTools()}),
            ("main_btn_undo_normal","ОТМЕНА",.original(0x009ac4),{[weak self] in self?.workspace.undo()})]
        for (row,entry) in entries.enumerated() {
            let (icon,title,color,action)=entry
            let button=UIButton(type:.custom);var config=UIButton.Configuration.plain();config.image=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/"+icon+".png").path)?.resizedIcon();config.title=title;config.imagePlacement = .top;config.imagePadding=0;config.contentInsets=NSDirectionalEdgeInsets(top:2,leading:2,bottom:2,trailing:2);config.baseForegroundColor=color;config.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{v in var x=v;x.font=UIFont(name:"Roboto-Regular",size:12) ?? .systemFont(ofSize:12);return x};button.configuration=config;button.addAction(UIAction{_ in action()},for:.touchUpInside);sidebar.addArrangedSubview(button)
            if row == 0 {button.accessibilityIdentifier="ProjectMenu";button.accessibilityLabel="Меню проекта"}
            button.heightAnchor.constraint(equalToConstant:[47.0,68,61,62,60,61][row]).isActive=true
        }
        sidebar.addArrangedSubview(UIView())
        navigation.distribution = .fill;navigation.backgroundColor = .clear
        let previous=UIButton(type:.custom),next=UIButton(type:.custom)
        for (control,name,label,offset) in [(previous,"main_prev_frame","Предыдущий кадр",-1),(next,"main_next_frame","Следующий кадр",1)] {
            for (suffix,state) in [("_np",UIControl.State.normal),("_pr",UIControl.State.highlighted)] {
                if let image=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/"+name+suffix+".png").path){control.setImage(image.resizedIcon(density:4),for:state)}
            }
            control.accessibilityLabel=label;control.heightAnchor.constraint(equalToConstant:60).isActive=true
            control.addAction(UIAction{[weak self] _ in self?.step(offset)},for:.touchUpInside)
        }
        navigation.addArrangedSubview(previous);navigation.addArrangedSubview(frameNavigator);navigation.addArrangedSubview(next)
        frameNavigator.seek = {[weak self] index in guard let self else{return};self.stop();self.workspace.index=index;self.workspace.notify()}
        NSLayoutConstraint.activate([
            sidebarScroll.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor),sidebarScroll.topAnchor.constraint(equalTo:view.topAnchor),sidebarScroll.bottomAnchor.constraint(equalTo:view.bottomAnchor),sidebarScroll.widthAnchor.constraint(equalToConstant:80),
            sidebar.leadingAnchor.constraint(equalTo:sidebarScroll.contentLayoutGuide.leadingAnchor),sidebar.trailingAnchor.constraint(equalTo:sidebarScroll.contentLayoutGuide.trailingAnchor),sidebar.topAnchor.constraint(equalTo:sidebarScroll.contentLayoutGuide.topAnchor),sidebar.bottomAnchor.constraint(equalTo:sidebarScroll.contentLayoutGuide.bottomAnchor),sidebar.widthAnchor.constraint(equalTo:sidebarScroll.frameLayoutGuide.widthAnchor),sidebar.heightAnchor.constraint(greaterThanOrEqualTo:sidebarScroll.frameLayoutGuide.heightAnchor),
            navigation.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor),navigation.topAnchor.constraint(equalTo:view.topAnchor),navigation.bottomAnchor.constraint(equalTo:view.bottomAnchor),navigation.widthAnchor.constraint(equalToConstant:60),
            canvas.leadingAnchor.constraint(equalTo:sidebar.trailingAnchor),canvas.trailingAnchor.constraint(equalTo:navigation.leadingAnchor),canvas.topAnchor.constraint(equalTo:view.topAnchor),canvas.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
        shift.translatesAutoresizingMaskIntoConstraints=false;shift.accessibilityLabel="Shift";shift.accessibilityHint="Удерживайте для растяжения разрешённых костей"
        shift.setImage(UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/shift_main.png").path),for:.normal)
        shift.imageView?.contentMode = .scaleAspectFit;shift.imageEdgeInsets=UIEdgeInsets(top:10,left:10,bottom:10,right:10)
        shift.addAction(UIAction{[weak self] _ in self?.canvas.stretch=true;self?.shift.alpha=0.6},for:.touchDown)
        shift.addAction(UIAction{[weak self] _ in self?.canvas.stretch=false;self?.shift.alpha=1},for:[.touchUpInside,.touchUpOutside,.touchCancel])
        view.addSubview(shift);NSLayoutConstraint.activate([shift.leadingAnchor.constraint(equalTo:sidebar.trailingAnchor),shift.topAnchor.constraint(equalTo:view.topAnchor),shift.widthAnchor.constraint(equalToConstant:48),shift.heightAnchor.constraint(equalToConstant:48)])
        workspace.onChange = {[weak self] in self?.update()};restoreAudio();update()
        if ProcessInfo.processInfo.arguments.contains("--reference-practice"),let url=Bundle.main.resourceURL?.appendingPathComponent("Content/Reference/practice.ats") {perform{try workspace.load(url)}}
        if ProcessInfo.processInfo.arguments.contains("--reference-attached") { workspace.installAttachedReference() }
        if ProcessInfo.processInfo.arguments.contains("--reference-animation"), let asset=workspace.catalog.first(where:{$0.name=="farid.things:semaphor"}) { workspace.document=SceneDocument(width:960,height:540,interframes:4,frames:[SceneFrame(id:0,units:[],attributes:[:])],attributes:[:]);workspace.index=0;workspace.add(asset);workspace.document.frames=(0..<20).map{SceneFrame(id:$0,units:workspace.frame.units,attributes:[:])};workspace.notify() }
        if ProcessInfo.processInfo.arguments.contains("--ui-capture"),let first=workspace.catalog.first(where:{$0.name.contains("boy")}){workspace.add(first)}
    }
    func button(_ title:String,_ action:@escaping()->Void)->UIButton{let b=UIButton(type:.system);b.setTitle(title,for:.normal);b.tintColor = .white;b.addAction(UIAction{_ in action()},for:.touchUpInside);return b}
    func update(){refreshFrameTools();refreshUnitTools();frameLabel.text="\(workspace.index+1) /\n\(workspace.document.frames.count)";frameNavigator.count=workspace.document.frames.count;frameNavigator.current=workspace.index;canvas.updateTransformControls();canvas.setNeedsDisplay()}
    func perform(_ work:()throws->Void){do{try work()}catch{message("Не удалось выполнить",String(describing:error))}}
    func message(_ title:String,_ text:String){let alert=UIAlertController(title:title,message:text,preferredStyle:.alert);alert.addAction(UIAlertAction(title:"OK",style:.default));present(alert,animated:true)}
    var backgroundController: BackgroundChooserController?
    var unitToolsActive = false
    var unitClipboard: [SceneUnit] = []
    var toolPanel:UIView?
    func dismissTools(){if let controller=backgroundController {controller.dismiss(animated:false);backgroundController=nil};unitToolsActive=false;if let controller=catalogController {controller.willMove(toParent:nil);controller.view.removeFromSuperview();controller.removeFromParent();catalogController=nil};toolPanel?.removeFromSuperview();toolPanel=nil;shift.isHidden=false;highlightFrameTools(false);highlightCatalog(false);highlightUnitTools(false)}
    func choices(_ title:String,_ actions:[(String,()->Void)]){
        stop();dismissTools()
        let cover=UIView(frame:view.bounds);cover.autoresizingMask=[.flexibleWidth,.flexibleHeight]
        let outside=UIButton(frame:cover.bounds);outside.autoresizingMask=[.flexibleWidth,.flexibleHeight];outside.backgroundColor=UIColor.black.withAlphaComponent(0.2);outside.addAction(UIAction{[weak self] _ in self?.dismissTools()},for:.touchUpInside);cover.addSubview(outside)
        let scroll=UIScrollView(frame:CGRect(x:view.safeAreaInsets.left+80,y:0,width:min(280,view.bounds.width-160),height:view.bounds.height));scroll.backgroundColor=UIColor(red:36/255,green:37/255,blue:48/255,alpha:1);scroll.autoresizingMask=[.flexibleHeight];cover.addSubview(scroll)
        let stack=UIStackView();stack.axis = .vertical;stack.spacing=1;stack.frame=CGRect(x:0,y:0,width:scroll.bounds.width,height:CGFloat(actions.count+1)*48)
        let heading=UILabel();heading.text=title;heading.textColor = .white;heading.textAlignment = .center;stack.addArrangedSubview(heading)
        for (name,action) in actions{let b=button(name,{[weak self] in self?.dismissTools();action()});b.titleLabel?.font=UIFont(name:"Roboto-Regular",size:14);b.contentHorizontalAlignment = .leading;b.contentEdgeInsets=UIEdgeInsets(top:0,left:14,bottom:0,right:10);b.backgroundColor=UIColor(white:1,alpha:0.04);stack.addArrangedSubview(b)}
        stack.distribution = .fillEqually;scroll.addSubview(stack);scroll.contentSize=stack.bounds.size;view.addSubview(cover);toolPanel=cover
    }
    func menu(){showProjectDrawer()}
    func newScene(){workspace.checkpoint();workspace.document=SceneDocument(width:960,height:540,interframes:4,frames:[SceneFrame(id:0,units:[],attributes:[:])],attributes:[:]);workspace.restoreArtwork();workspace.index=0;workspace.selected=nil;workspace.latchedUnitName=nil;workspace.notify()}
    private var catalogController: CatalogController?
    func highlightCatalog(_ active: Bool) {
        guard let button = sidebar.arrangedSubviews[2] as? UIButton else { return }
        var configuration = button.configuration
        configuration?.background.backgroundColor = active ? .original(0x72bd00) : .clear
        let icon = configuration?.image?.withRenderingMode(active ? .alwaysTemplate : .alwaysOriginal)
        configuration?.image = icon
        configuration?.background.cornerRadius = 0
        configuration?.baseForegroundColor = active ? .white : .original(0x72bd00)
        button.configuration = configuration
    }
    func objects() {
        if catalogController != nil { dismissTools(); return }
        stop(); dismissTools()
        let picker = CatalogController(workspace.catalog, resolve: workspace.artworkURL, close: { [weak self] in self?.dismissTools() }, importATI: { [weak self] in self?.importUserATI() }) { [weak self] asset in self?.workspace.add(asset) }
        addChild(picker); picker.view.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(picker.view)
        NSLayoutConstraint.activate([picker.view.leadingAnchor.constraint(equalTo: sidebarScroll.trailingAnchor), picker.view.topAnchor.constraint(equalTo: view.topAnchor), picker.view.bottomAnchor.constraint(equalTo: view.bottomAnchor), picker.view.widthAnchor.constraint(equalToConstant: 180)])
        picker.didMove(toParent: self); catalogController = picker; toolPanel = picker.view; shift.isHidden = true; highlightCatalog(true)
    }
    func objectTools(){if unitToolsActive {dismissTools();return};stop();showUnitTools()}
    func selectObject(){workspace.selected=nil;showUnitList()}
    var frameClipboard: [SceneFrame] = []
    func highlightFrameTools(_ active: Bool) {
        guard sidebar.arrangedSubviews.indices.contains(4), let button = sidebar.arrangedSubviews[4] as? UIButton else { return }
        var configuration = button.configuration
        let icon = configuration?.image?.withRenderingMode(active ? .alwaysTemplate : .alwaysOriginal)
        configuration?.image = icon
        configuration?.background.cornerRadius = 0
        configuration?.background.backgroundColor = active ? .original(0x449ec9) : .clear
        configuration?.baseForegroundColor = active ? .white : .original(0x449ec9)
        button.configuration = configuration
    }
    func refreshFrameTools() {
        guard let panel = toolPanel as? FrameToolsPanel else { return }
        panel.setEnabled(!frameClipboard.isEmpty, for: "frame_ops_paste")
        panel.setEnabled(workspace.document.frames.count > 1, for: "frame_ops_del")
    }
    func frameTools() {
        if toolPanel?.accessibilityIdentifier == "FrameToolsPanel" { dismissTools(); return }
        stop(); dismissTools()
        let panel = FrameToolsPanel(commands: [
            .init(id: "frame_ops_add", title: "Добавить", height: 81, enabled: true, action: { [weak self] in self?.perform { try self?.workspace.addFrame() } }),
            .init(id: "frame_ops_del", title: "Удалить", height: 81, enabled: workspace.document.frames.count > 1, action: { [weak self] in self?.workspace.deleteFrame() }),
            .init(id: "frame_ops_copy", title: "Копировать", height: 81, enabled: true, action: { [weak self] in
                guard let self else { return }; self.frameClipboard = [self.workspace.frame]; self.refreshFrameTools()
            }),
            .init(id: "frame_ops_paste", title: "Вставить", height: 81, enabled: !frameClipboard.isEmpty, action: { [weak self] in self?.pasteFrames() }),
            .init(id: "frame_ops_paste_scene", title: "Вст.\nсцену", height: 95, enabled: true, action: { [weak self] in self?.scenesToInsert() })
        ])
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(panel, belowSubview: shift)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: sidebarScroll.trailingAnchor),
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.widthAnchor.constraint(equalToConstant: 86)
        ])
        toolPanel = panel; shift.isHidden = true; highlightFrameTools(true)
    }
    func pasteFrames() {
        guard !frameClipboard.isEmpty else { return }
        var next = workspace.document
        guard FrameClipboard.paste(frameClipboard, into: &next, currentIndex: workspace.index) != nil else { return }
        workspace.checkpoint(); workspace.document = next; workspace.selected = nil; workspace.notify()
    }
    func scenesToInsert() {
        let files = ((try? FileManager.default.contentsOfDirectory(at: workspace.directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasSuffix(".animation.json") && $0.lastPathComponent != "Autosave.animation.json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !files.isEmpty else { dismissTools(); message("Вставить сцену", "Сначала сохраните сцену, которую хотите вставить."); return }
        choices("Вставить сцену", files.map { url in
            (url.lastPathComponent.replacingOccurrences(of: ".animation.json", with: ""), { [weak self] in
                self?.perform {
                    guard let self else { return }
                    let source = try JSONDecoder().decode(SceneDocument.self, from: Data(contentsOf: url))
                    guard !source.frames.isEmpty else { throw SceneReadError.invalidScene }
                    if let artwork = source.attributes["nativeArtworkDirectory"], artwork != self.workspace.document.attributes["nativeArtworkDirectory"] {
                        self.message("Вставить сцену", "Вставка сцены с другим набором пользовательских рисунков пока недоступна."); return
                    }
                    let previousClipboard = self.frameClipboard
                    self.frameClipboard = source.frames; self.pasteFrames(); self.frameClipboard = previousClipboard
                    self.frameTools()
                }
            })
        })
    }
    func step(_ offset:Int){stop();if offset>0 && workspace.index==workspace.document.frames.count-1 {perform{try workspace.addFrame()}}else{workspace.index=min(max(0,workspace.index+offset),workspace.document.frames.count-1);workspace.notify()}}
    func stop(){displayLink?.invalidate();displayLink=nil;canvas.displayed=nil;audio?.pause();update()}
    func togglePlayback(){stop();present(PreviewController(workspace:workspace,audio:audio),animated:false)}
    func frameAt(_ elapsed:Double)->SceneFrame {
        let perKey=max(1,workspace.document.interframes+1);let count=workspace.document.frames.count;let position=min(Double(count-1),max(0,elapsed*60/Double(perKey)+Double(startFrame)));let index=Int(position);let t=position-floor(position);let frame=workspace.document.frames[index],next=workspace.document.frames[min(index+1,count-1)]
        return workspace.applyAssetAnimations(to:(try? FrameInterpolation.between(frame,next,progress:t)) ?? frame,tick:Int(max(0,elapsed*60))+startFrame*perKey)
    }
    @objc func tick(_ link:CADisplayLink){canvas.displayed=frameAt(link.timestamp-playbackStart);canvas.setNeedsDisplay()}
    func save(){let alert=UIAlertController(title:"Сохранить сцену",message:nil,preferredStyle:.alert);alert.addTextField{$0.text=self.titleOfScene};alert.addAction(UIAlertAction(title:"Сохранить",style:.default){[weak self] _ in guard let self else{return};self.titleOfScene=alert.textFields?.first?.text ?? "Animation";self.perform{let url = try self.workspace.save(name:self.titleOfScene)
            let thumbnail = self.canvas.snapshot(size: CGSize(width: 320, height: 128))
            try? thumbnail.pngData()?.write(to: url.appendingPathExtension("png"), options: .atomic)}});alert.addAction(UIAlertAction(title:"Отмена",style:.cancel));present(alert,animated:true)}
    var importingBackgroundImage=false
    var importingUserATI=false
    func importUserATI(){importingUserATI=true;pickingAudio=false;let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.data],asCopy:true);picker.delegate=self;present(picker,animated:true)}
    func documentPickerWasCancelled(_ controller:UIDocumentPickerViewController){importingUserATI=false;importingBackgroundImage=false}
    var pickingAudio=false
    func openFiles(){pickingAudio=false;let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.data],asCopy:true);picker.delegate=self;present(picker,animated:true)}
    func savedScenes(){let files=(try? FileManager.default.contentsOfDirectory(at:workspace.directory,includingPropertiesForKeys:nil)) ?? [];choices("Мои сцены",files.filter{$0.lastPathComponent.hasSuffix(".animation.json")}.map{url in (url.deletingPathExtension().lastPathComponent,{[weak self] in self?.perform{try self?.workspace.load(url);self?.restoreAudio()}})})}
    func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]){guard let url=urls.first else{return};perform{if importingBackgroundImage {importingBackgroundImage=false;try installBackgroundImage(url)}else if importingUserATI {importingUserATI=false;_ = try UserSpriteLibrary.importATI(url,directory:workspace.directory);workspace.restoreArtwork();catalogController?.updateAssets(workspace.catalog);workspace.notify()}else if pickingAudio {let scoped=url.startAccessingSecurityScopedResource();defer{if scoped{url.stopAccessingSecurityScopedResource()}};let target=workspace.directory.appendingPathComponent(UUID().uuidString+"."+url.pathExtension);try FileManager.default.copyItem(at:url,to:target);workspace.document.attributes["nativeAudio"]=target.lastPathComponent;audio=try AVAudioPlayer(contentsOf:target);audio?.prepareToPlay();workspace.notify()}else{try workspace.load(url);restoreAudio()}}}
    var audio:AVAudioPlayer?
    func restoreAudio(){audio=nil;if let name=workspace.document.attributes["nativeAudio"],!name.contains("/"),let player=try? AVAudioPlayer(contentsOf:workspace.directory.appendingPathComponent(name)){audio=player;audio?.prepareToPlay()}}

    func audioPicker(){pickingAudio=true;let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.audio],asCopy:true);picker.delegate=self;present(picker,animated:true)}
    func closeBackgroundChooser(_ completion:@escaping()->Void = {}) {let chooser=backgroundController;backgroundController=nil;chooser?.dismiss(animated:false,completion:completion)}
    func backgrounds() {
        stop();dismissTools()
        let chooser=BackgroundChooserController(values:workspace.backgroundCatalog,select:{[weak self] value in
            guard let self else{return};self.workspace.checkpoint();self.workspace.document.frames[self.workspace.index].attributes["nativeBackgroundID"]=value?.id;self.workspace.document.frames[self.workspace.index].attributes.removeValue(forKey:"nativeBackgroundImage");self.workspace.document.frames[self.workspace.index].attributes.removeValue(forKey:"nativeBackgroundColor");self.workspace.notify()
        },close:{[weak self] in self?.closeBackgroundChooser()},actions:[{[weak self] in self?.closeBackgroundChooser{[weak self] in self?.pickBackgroundColor()}},{[weak self] in self?.closeBackgroundChooser{[weak self] in self?.pickBackgroundImage()}},{[weak self] in self?.closeBackgroundChooser{[weak self] in self?.drawBackground()}}],resolve:workspace.artworkURL)
        chooser.modalPresentationStyle = .overFullScreen;backgroundController=chooser;present(chooser,animated:false)
    }
    func properties(){let a=UIAlertController(title:"Сцена",message:"Ширина, высота и промежуточные кадры",preferredStyle:.alert);for value in [Int(workspace.document.width),Int(workspace.document.height),workspace.document.interframes]{a.addTextField{$0.text=String(value);$0.keyboardType = .numberPad}};a.addAction(UIAlertAction(title:"OK",style:.default){[weak self] _ in guard let self,let f=a.textFields,let w=Double(f[0].text ?? ""),let h=Double(f[1].text ?? ""),let n=Int(f[2].text ?? ""),w>0,h>0,w<=4096,h<=4096,n>=0,n<120 else{return};self.workspace.checkpoint();self.workspace.document.width=w;self.workspace.document.height=h;self.workspace.document.interframes=n;self.update()});a.addAction(UIAlertAction(title:"Отмена",style:.cancel));present(a,animated:true)}
    func exports(){choices("Экспорт",[("ATS-проект",{[weak self] in self?.perform{guard let self else{return};self.share(try self.workspace.saveATS())}}),("MP4 со звуком",{[weak self] in self?.exportVideo()}),("PNG текущего кадра",{[weak self] in self?.exportPNG()}),("GIF анимация",{[weak self] in self?.exportGIF()}),("Файл проекта JSON",{[weak self] in self?.perform{guard let self else{return};self.share(try self.workspace.save(name:self.titleOfScene))}})])}
    func share(_ url:URL){let vc=UIActivityViewController(activityItems:[url],applicationActivities:nil);vc.popoverPresentationController?.sourceView=sidebar;vc.popoverPresentationController?.sourceRect=sidebar.bounds;present(vc,animated:true)}
    func exportPNG(){perform{let url=FileManager.default.temporaryDirectory.appendingPathComponent("frame.png");try canvas.snapshot(size:CGSize(width:workspace.document.width,height:workspace.document.height)).pngData()?.write(to:url);share(url)}}
    func exportGIF(){stop();let n=workspace.document.frames.count*max(1,workspace.document.interframes+1);guard n<=1800 else{message("Слишком длинная анимация","GIF ограничен 1800 кадрами. Проект сохранён без сокращения.");return};let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".gif");guard let destination=CGImageDestinationCreateWithURL(url as CFURL,UTType.gif.identifier as CFString,n,nil) else{return};CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary);let oldStart=startFrame;startFrame=0;for i in 0..<n{autoreleasepool{canvas.displayed=frameAt(Double(i)/60);if let image=canvas.snapshot(size:CGSize(width:workspace.document.width,height:workspace.document.height)).cgImage{CGImageDestinationAddImage(destination,image,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFUnclampedDelayTime:1.0/60]] as CFDictionary)}}};canvas.displayed=nil;startFrame=oldStart;if CGImageDestinationFinalize(destination){share(url)}else{message("Ошибка экспорта","Не удалось записать GIF")};update()}
}

extension UIImage {func resizedIcon(density:CGFloat=3)->UIImage {let size=CGSize(width:size.width/density,height:size.height/density);return UIGraphicsImageRenderer(size:size).image{_ in draw(in:CGRect(origin:.zero,size:size))}.withRenderingMode(.alwaysOriginal)}}
extension UIColor {static func original(_ rgb:UInt32)->UIColor{UIColor(red:CGFloat((rgb>>16)&255)/255,green:CGFloat((rgb>>8)&255)/255,blue:CGFloat(rgb&255)/255,alpha:1)}}
