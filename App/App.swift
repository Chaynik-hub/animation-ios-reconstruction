import UIKit
import UniformTypeIdentifiers
import ImageIO
import AVFoundation

@main final class AppDelegate:UIResponder,UIApplicationDelegate {
    var window:UIWindow?
    func application(_ application:UIApplication,didFinishLaunchingWithOptions options:[UIApplication.LaunchOptionsKey:Any]?)->Bool {
        let window=UIWindow(frame:UIScreen.main.bounds);window.rootViewController=EditorController();window.makeKeyAndVisible();self.window=window;return true
    }
}

final class EditorController:UIViewController,UIDocumentPickerDelegate {
    let workspace=Workspace()
    lazy var canvas=SceneCanvas(workspace)
    let sidebar=UIStackView(),navigation=UIStackView(),frameLabel=UILabel()
    var displayLink:CADisplayLink?
    var playbackStart:CFTimeInterval=0
    var startFrame=0
    var titleOfScene="Animation"
    override var prefersStatusBarHidden:Bool{true}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor=UIColor(red:36/255,green:37/255,blue:48/255,alpha:1)
        canvas.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(canvas)
        for stack in [sidebar,navigation]{stack.axis = .vertical;stack.distribution = .fillEqually;stack.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(stack)}
        sidebar.backgroundColor=view.backgroundColor;navigation.backgroundColor=view.backgroundColor
        let entries:[(String,String,UIColor,()->Void)]=[
            ("main_btn_nav","",.white,{[weak self] in self?.menu()}),
            ("main_btn_play","ПУСК",.orange,{[weak self] in self?.togglePlayback()}),
            ("main_btn_insert","ДОБАВИТЬ",.systemGreen,{[weak self] in self?.objects()}),
            ("main_btn_props","РЕДАКТ.",.systemTeal,{[weak self] in self?.objectTools()}),
            ("main_btn_frames","РЕД. КАДР",.systemBlue,{[weak self] in self?.frameTools()}),
            ("main_btn_undo_normal","ОТМЕНА",.cyan,{[weak self] in self?.workspace.undo()})]
        for (icon,title,color,action) in entries {
            let button=UIButton(type:.custom);var config=UIButton.Configuration.plain();config.image=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/"+icon+".png").path)?.resizedIcon();config.title=title;config.imagePlacement = .top;config.imagePadding=2;config.baseForegroundColor=color;config.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{v in var x=v;x.font=UIFont(name:"Roboto-Regular",size:12) ?? .systemFont(ofSize:12);return x};button.configuration=config;button.addAction(UIAction{_ in action()},for:.touchUpInside);sidebar.addArrangedSubview(button)
        }
        let navEntries: [(String,()->Void)] = [("+",{[weak self] in self?.perform{try self?.workspace.addFrame()}}),("▲",{[weak self] in self?.step(-1)}),("▼",{[weak self] in self?.step(1)})]
        for (title,action) in navEntries {let b=button(title,action);navigation.addArrangedSubview(b)}
        frameLabel.textColor = .white;frameLabel.textAlignment = .center;frameLabel.numberOfLines=2;frameLabel.font = .monospacedDigitSystemFont(ofSize:14,weight:.regular);navigation.addArrangedSubview(frameLabel)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor),sidebar.topAnchor.constraint(equalTo:view.topAnchor),sidebar.bottomAnchor.constraint(equalTo:view.bottomAnchor),sidebar.widthAnchor.constraint(equalToConstant:80),
            navigation.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor),navigation.topAnchor.constraint(equalTo:view.topAnchor),navigation.bottomAnchor.constraint(equalTo:view.bottomAnchor),navigation.widthAnchor.constraint(equalToConstant:60),
            canvas.leadingAnchor.constraint(equalTo:sidebar.trailingAnchor),canvas.trailingAnchor.constraint(equalTo:navigation.leadingAnchor),canvas.topAnchor.constraint(equalTo:view.topAnchor),canvas.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
        workspace.onChange = {[weak self] in self?.update()};restoreAudio();update()
        if ProcessInfo.processInfo.arguments.contains("--ui-capture"),let first=workspace.catalog.first(where:{$0.name.contains("boy")}){workspace.add(first)}
    }
    func button(_ title:String,_ action:@escaping()->Void)->UIButton{let b=UIButton(type:.system);b.setTitle(title,for:.normal);b.tintColor = .white;b.addAction(UIAction{_ in action()},for:.touchUpInside);return b}
    func update(){frameLabel.text="\(workspace.index+1) /\n\(workspace.document.frames.count)";canvas.setNeedsDisplay()}
    func perform(_ work:()throws->Void){do{try work()}catch{message("Не удалось выполнить",String(describing:error))}}
    func message(_ title:String,_ text:String){let alert=UIAlertController(title:title,message:text,preferredStyle:.alert);alert.addAction(UIAlertAction(title:"OK",style:.default));present(alert,animated:true)}
    var toolPanel:UIView?
    func dismissTools(){toolPanel?.removeFromSuperview();toolPanel=nil}
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
    func menu(){choices("Проект",[("Новая сцена",{[weak self] in self?.newScene()}),("Сохранить",{[weak self] in self?.save()}),("Открыть",{[weak self] in self?.openFiles()}),("Мои сцены",{[weak self] in self?.savedScenes()}),("Экспорт",{[weak self] in self?.exports()}),("Фон",{[weak self] in self?.backgrounds()}),("Параметры сцены",{[weak self] in self?.properties()}),("Звук",{[weak self] in self?.audioPicker()})])}
    func newScene(){workspace.checkpoint();workspace.document=SceneDocument(width:960,height:540,interframes:4,frames:[SceneFrame(id:0,units:[],attributes:[:])],attributes:[:]);workspace.index=0;workspace.selected=nil;workspace.notify()}
    func objects(){stop();let picker=CatalogController(workspace.catalog){[weak self] asset in self?.workspace.add(asset)};picker.modalPresentationStyle = .overFullScreen;present(picker,animated:true)}
    func objectTools(){choices("Объект",[("Выбрать объект",{[weak self] in self?.selectObject()}),("Отразить",{[weak self] in self?.workspace.flip()}),("Дублировать",{[weak self] in guard let self,let i=self.workspace.selected,self.workspace.frame.units.indices.contains(i) else{return};self.workspace.checkpoint();var u=self.workspace.frame.units[i];u.name += "#"+UUID().uuidString;self.workspace.document.frames[self.workspace.index].units.append(u);self.workspace.selected=self.workspace.frame.units.count-1;self.workspace.notify()}),("Удалить",{[weak self] in self?.workspace.removeObject()}),("Показать/скрыть суставы",{[weak self] in self?.canvas.handles.toggle();self?.canvas.setNeedsDisplay()})])}
    func selectObject(){choices("Выбрать",workspace.frame.units.enumerated().map{i,u in (u.name.components(separatedBy:"#")[0],{[weak self] in self?.workspace.selected=i;self?.update()})})}
    func frameTools(){choices("Кадры",[("Добавить промежуточный / копию",{[weak self] in self?.perform{try self?.workspace.addFrame()}}),("Удалить кадр",{[weak self] in self?.workspace.deleteFrame()}),("Копировать кадр",{[weak self] in self?.clipboard=self?.workspace.frame}),("Вставить кадр",{[weak self] in guard let self,var f=self.clipboard else{return};self.workspace.checkpoint();f.id=(self.workspace.document.frames.map(\.id).max() ?? 0)+1;self.workspace.document.frames.insert(f,at:self.workspace.index+1);self.workspace.index+=1;self.workspace.notify()}),("Предыдущий кадр полупрозрачно",{[weak self] in self?.canvas.onion.toggle();self?.update()}),("Повторить действие",{[weak self] in self?.workspace.redo()})])}
    var clipboard:SceneFrame?
    func step(_ offset:Int){stop();workspace.index=min(max(0,workspace.index+offset),workspace.document.frames.count-1);workspace.notify()}
    func stop(){displayLink?.invalidate();displayLink=nil;canvas.displayed=nil;audio?.pause();update()}
    func togglePlayback(){stop();present(PreviewController(workspace:workspace,audio:audio),animated:false)}
    func frameAt(_ elapsed:Double)->SceneFrame {
        let perKey=max(1,workspace.document.interframes+1);let position=elapsed*60/Double(perKey)+Double(startFrame);let count=workspace.document.frames.count;let index=Int(position)%count;let t=position-floor(position);var frame=workspace.document.frames[index];let next=workspace.document.frames[(index+1)%count]
        for i in frame.units.indices{if let end=next.units.first(where:{$0.name==frame.units[i].name}),let pose=try? PoseInterpolation.between(frame.units[i],end,progress:t){frame.units[i]=pose}};return frame
    }
    @objc func tick(_ link:CADisplayLink){canvas.displayed=frameAt(link.timestamp-playbackStart);canvas.setNeedsDisplay()}
    func save(){let alert=UIAlertController(title:"Сохранить сцену",message:nil,preferredStyle:.alert);alert.addTextField{$0.text=self.titleOfScene};alert.addAction(UIAlertAction(title:"Сохранить",style:.default){[weak self] _ in guard let self else{return};self.titleOfScene=alert.textFields?.first?.text ?? "Animation";self.perform{_ = try self.workspace.save(name:self.titleOfScene)}});alert.addAction(UIAlertAction(title:"Отмена",style:.cancel));present(alert,animated:true)}
    var pickingAudio=false
    func openFiles(){pickingAudio=false;let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.data],asCopy:true);picker.delegate=self;present(picker,animated:true)}
    func savedScenes(){let files=(try? FileManager.default.contentsOfDirectory(at:workspace.directory,includingPropertiesForKeys:nil)) ?? [];choices("Мои сцены",files.filter{$0.lastPathComponent.hasSuffix(".animation.json")}.map{url in (url.deletingPathExtension().lastPathComponent,{[weak self] in self?.perform{try self?.workspace.load(url);self?.restoreAudio()}})})}
    func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]){guard let url=urls.first else{return};perform{if pickingAudio {let scoped=url.startAccessingSecurityScopedResource();defer{if scoped{url.stopAccessingSecurityScopedResource()}};let target=workspace.directory.appendingPathComponent(UUID().uuidString+"."+url.pathExtension);try FileManager.default.copyItem(at:url,to:target);workspace.document.attributes["nativeAudio"]=target.lastPathComponent;audio=try AVAudioPlayer(contentsOf:target);audio?.prepareToPlay();workspace.notify()}else{try workspace.load(url);restoreAudio()}}}
    var audio:AVAudioPlayer?
    func restoreAudio(){audio=nil;if let name=workspace.document.attributes["nativeAudio"],!name.contains("/"),let player=try? AVAudioPlayer(contentsOf:workspace.directory.appendingPathComponent(name)){audio=player;audio?.prepareToPlay()}}

    func audioPicker(){pickingAudio=true;let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.audio],asCopy:true);picker.delegate=self;present(picker,animated:true)}
    func backgrounds(){choices("Цвет фона",[("Белый",{[weak self] in self?.canvas.backgroundColorValue = .white;self?.update()}),("Чёрный",{[weak self] in self?.canvas.backgroundColorValue = .black;self?.update()}),("Зелёный",{[weak self] in self?.canvas.backgroundColorValue = .green;self?.update()}),("Сбросить масштаб камеры",{[weak self] in self?.canvas.cameraScale=1;self?.canvas.cameraOffset = .zero;self?.update()})])}
    func properties(){let a=UIAlertController(title:"Сцена",message:"Ширина, высота и промежуточные кадры",preferredStyle:.alert);for value in [Int(workspace.document.width),Int(workspace.document.height),workspace.document.interframes]{a.addTextField{$0.text=String(value);$0.keyboardType = .numberPad}};a.addAction(UIAlertAction(title:"OK",style:.default){[weak self] _ in guard let self,let f=a.textFields,let w=Double(f[0].text ?? ""),let h=Double(f[1].text ?? ""),let n=Int(f[2].text ?? ""),w>0,h>0,w<=4096,h<=4096,n>=0,n<120 else{return};self.workspace.checkpoint();self.workspace.document.width=w;self.workspace.document.height=h;self.workspace.document.interframes=n;self.update()});a.addAction(UIAlertAction(title:"Отмена",style:.cancel));present(a,animated:true)}
    func exports(){choices("Экспорт",[("MP4 со звуком",{[weak self] in self?.exportVideo()}),("PNG текущего кадра",{[weak self] in self?.exportPNG()}),("GIF анимация",{[weak self] in self?.exportGIF()}),("Файл проекта JSON",{[weak self] in self?.perform{guard let self else{return};self.share(try self.workspace.save(name:self.titleOfScene))}})])}
    func share(_ url:URL){let vc=UIActivityViewController(activityItems:[url],applicationActivities:nil);vc.popoverPresentationController?.sourceView=sidebar;vc.popoverPresentationController?.sourceRect=sidebar.bounds;present(vc,animated:true)}
    func exportPNG(){perform{let url=FileManager.default.temporaryDirectory.appendingPathComponent("frame.png");try canvas.snapshot(size:CGSize(width:workspace.document.width,height:workspace.document.height)).pngData()?.write(to:url);share(url)}}
    func exportGIF(){stop();let n=workspace.document.frames.count*max(1,workspace.document.interframes+1);guard n<=1800 else{message("Слишком длинная анимация","GIF ограничен 1800 кадрами. Проект сохранён без сокращения.");return};let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".gif");guard let destination=CGImageDestinationCreateWithURL(url as CFURL,UTType.gif.identifier as CFString,n,nil) else{return};CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary);let oldStart=startFrame;startFrame=0;for i in 0..<n{autoreleasepool{canvas.displayed=frameAt(Double(i)/60);if let image=canvas.snapshot(size:CGSize(width:workspace.document.width,height:workspace.document.height)).cgImage{CGImageDestinationAddImage(destination,image,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFUnclampedDelayTime:1.0/60]] as CFDictionary)}}};canvas.displayed=nil;startFrame=oldStart;if CGImageDestinationFinalize(destination){share(url)}else{message("Ошибка экспорта","Не удалось записать GIF")};update()}
}

extension UIImage {func resizedIcon()->UIImage {let size=CGSize(width:size.width/3,height:size.height/3);return UIGraphicsImageRenderer(size:size).image{_ in draw(in:CGRect(origin:.zero,size:size))}.withRenderingMode(.alwaysOriginal)}}
final class CatalogController:UIViewController,UICollectionViewDataSource,UICollectionViewDelegate {
    let assets:[ArtworkDefinition],pick:(ArtworkDefinition)->Void
    var collection:UICollectionView!
    init(_ assets:[ArtworkDefinition],pick:@escaping(ArtworkDefinition)->Void){self.assets=assets;self.pick=pick;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError()}
    override func viewDidLoad(){super.viewDidLoad();let layout=UICollectionViewFlowLayout();layout.itemSize=CGSize(width:110,height:120);layout.sectionInset=UIEdgeInsets(top:20,left:20,bottom:20,right:20);collection=UICollectionView(frame:view.bounds,collectionViewLayout:layout);collection.autoresizingMask=[.flexibleWidth,.flexibleHeight];collection.backgroundColor=UIColor(red:36/255,green:37/255,blue:48/255,alpha:1);collection.register(UICollectionViewCell.self,forCellWithReuseIdentifier:"item");collection.dataSource=self;collection.delegate=self;view.addSubview(collection)}
    func collectionView(_ collectionView:UICollectionView,numberOfItemsInSection section:Int)->Int{assets.count}
    func collectionView(_ collectionView:UICollectionView,cellForItemAt indexPath:IndexPath)->UICollectionViewCell{let cell=collectionView.dequeueReusableCell(withReuseIdentifier:"item",for:indexPath);cell.contentView.subviews.forEach{$0.removeFromSuperview()};let asset=assets[indexPath.item];let image=UIImageView(frame:CGRect(x:5,y:0,width:100,height:90));image.contentMode = .scaleAspectFit;if let path=asset.thumbnail{image.image=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/"+path).path)};cell.contentView.addSubview(image);let label=UILabel(frame:CGRect(x:0,y:92,width:110,height:28));label.text=asset.name;label.textColor = .white;label.font = .systemFont(ofSize:11);label.textAlignment = .center;cell.contentView.addSubview(label);return cell}
    func collectionView(_ collectionView:UICollectionView,didSelectItemAt indexPath:IndexPath){let asset=assets[indexPath.item];dismiss(animated:true){self.pick(asset)}}
}
