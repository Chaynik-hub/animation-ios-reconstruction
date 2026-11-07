import UIKit
import UniformTypeIdentifiers

struct UserBackgroundLibrary {
    static func list(in directory:URL)->[BackgroundDefinition] {
        guard let data=try? Data(contentsOf:directory.appendingPathComponent("BackgroundImports/index.json")),data.count<2*1024*1024 else{return []}
        return (try? JSONDecoder().decode([BackgroundDefinition].self,from:data)) ?? []
    }
    static func save(_ image:UIImage,title:String,directory:URL)throws->BackgroundDefinition {
        guard image.size.width>0,image.size.height>0,image.size.width*image.size.height<=32_000_000 else{throw SceneReadError.resourceLimit}
        let id=UUID().uuidString,folder=directory.appendingPathComponent("BackgroundImports",isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let scale=min(1,4096/max(image.size.width,image.size.height)),size=CGSize(width:image.size.width*scale,height:image.size.height*scale)
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let rendered=UIGraphicsImageRenderer(size:size,format:format).image{_ in image.draw(in:CGRect(origin:.zero,size:size))}
        guard let data=rendered.pngData() else{throw SceneReadError.invalidScene};try data.write(to:folder.appendingPathComponent(id+".png"),options:.atomic)
        let thumb=UIGraphicsImageRenderer(size:CGSize(width:90,height:90),format:format).image{_ in image.draw(in:CGRect(x:0,y:0,width:90,height:90))}
        try thumb.pngData()?.write(to:folder.appendingPathComponent(id+"-thumb.png"),options:.atomic)
        let value=BackgroundDefinition(id:"@custom:"+id,pack:"@custom",title:title,image:"@local/BackgroundImports/"+id+".png",thumbnail:"@local/BackgroundImports/"+id+"-thumb.png")
        var values=list(in:directory);values.append(value);try JSONEncoder().encode(values).write(to:folder.appendingPathComponent("index.json"),options:.atomic);return value
    }
}
extension EditorController: UIColorPickerViewControllerDelegate {
    func pickBackgroundColor(){let picker=UIColorPickerViewController();picker.delegate=self;picker.supportsAlpha=true;present(picker,animated:false)}
    func colorPickerViewControllerDidFinish(_ viewController:UIColorPickerViewController){
        var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=1;guard viewController.selectedColor.getRed(&r,green:&g,blue:&b,alpha:&a) else{return}
        viewController.dismiss(animated: false) { [weak self] in
            self?.chooseBackgroundScope(["nativeBackgroundColor": "\(r),\(g),\(b),\(a)"])
        }
    }
    func pickBackgroundImage(){importingBackgroundImage=true;importingUserATI=false;pickingAudio=false;let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.image],asCopy:true);picker.delegate=self;present(picker,animated:false)}
    func installBackgroundImage(_ url:URL)throws {
        let scope=url.startAccessingSecurityScopedResource();defer{if scope{url.stopAccessingSecurityScopedResource()}}
        guard let image=UIImage(contentsOfFile:url.path) else{throw SceneReadError.invalidScene}
        let entry=try UserBackgroundLibrary.save(image,title:url.deletingPathExtension().lastPathComponent,directory:workspace.directory);selectUserBackground(entry)
    }
    func selectUserBackground(_ entry: BackgroundDefinition) {
        workspace.backgroundLibraryCache = nil
        chooseBackgroundScope(["nativeBackgroundID": entry.id])
    }

    func chooseBackgroundScope(_ attributes: [String: String]) {
        let alert = UIAlertController(title: "Применить фон", message: nil, preferredStyle: .alert)
        for (label, all) in [("На текущий кадр", false), ("На все кадры", true)] {
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                guard let self else { return }
                self.workspace.checkpoint()
                let indices = all ? self.workspace.document.frames.indices : self.workspace.index..<(self.workspace.index + 1)
                for index in indices {
                    for key in ["nativeBackgroundID", "nativeBackgroundColor", "nativeBackgroundImage"] {
                        self.workspace.document.frames[index].attributes[key] = attributes[key]
                    }
                }
                self.workspace.notify()
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
    func drawBackground(){let controller=BackgroundDrawingController(size:CGSize(width:workspace.document.width,height:workspace.document.height)){[weak self] image in self?.perform{guard let self else{return};let entry=try UserBackgroundLibrary.save(image,title:"Рисунок",directory:self.workspace.directory);self.selectUserBackground(entry)}};controller.modalPresentationStyle = .fullScreen;present(controller,animated:false)}
}

private final class BackgroundPaper:UIView {
    var strokes:[(UIBezierPath,UIColor,CGFloat)]=[],color=UIColor.black,width:CGFloat=4
    override init(frame:CGRect){super.init(frame:frame);backgroundColor = .white;isMultipleTouchEnabled=false}
    required init?(coder:NSCoder){fatalError()}
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?){guard let touch=touches.first else{return};let path=UIBezierPath();path.move(to:touch.location(in:self));strokes.append((path,color,width));setNeedsDisplay()}
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?){guard let touch=touches.first,let last=strokes.last else{return};last.0.addLine(to:touch.location(in:self));setNeedsDisplay()}
    override func draw(_ rect:CGRect){UIColor.white.setFill();UIRectFill(bounds);for (path,color,width) in strokes{color.setStroke();path.lineWidth=width;path.lineCapStyle = .round;path.lineJoinStyle = .round;path.stroke()}}
    func image(size:CGSize)->UIImage{let format=UIGraphicsImageRendererFormat();format.scale=1;return UIGraphicsImageRenderer(size:size,format:format).image{context in context.cgContext.scaleBy(x:size.width/max(1,bounds.width),y:size.height/max(1,bounds.height));draw(bounds)}}
}
final class BackgroundDrawingController:UIViewController {
    private let paper=BackgroundPaper(),size:CGSize,save:(UIImage)->Void
    init(size:CGSize,save:@escaping(UIImage)->Void){self.size=size;self.save=save;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError()}
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor = .original(0x24252f);paper.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(paper)
        let tools=UIStackView();tools.spacing=8;tools.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(tools)
        let palette=UISegmentedControl(items:["Чёрный","Красный","Синий","Зелёный"]);palette.selectedSegmentIndex=0;palette.addAction(UIAction{[weak self,weak palette] _ in guard let self,let palette else{return};self.paper.color=[.black,.red,.blue,.green][palette.selectedSegmentIndex]},for:.valueChanged);tools.addArrangedSubview(palette)
        for (title,action) in [("Отмена штриха",{[weak self] in _ = self?.paper.strokes.popLast();self?.paper.setNeedsDisplay()}),("Готово",{[weak self] in guard let self else{return};let image=self.paper.image(size:self.size);self.dismiss(animated:false){self.save(image)}}),("Закрыть",{[weak self] in self?.dismiss(animated:false)})] {let button=UIButton(type:.system);button.setTitle(title,for:.normal);button.tintColor = .white;button.addAction(UIAction{_ in action()},for:.touchUpInside);tools.addArrangedSubview(button)}
        NSLayoutConstraint.activate([tools.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:8),tools.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-8),tools.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),tools.heightAnchor.constraint(equalToConstant:45),paper.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor),paper.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor),paper.topAnchor.constraint(equalTo:tools.bottomAnchor),paper.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor)])
    }
}
