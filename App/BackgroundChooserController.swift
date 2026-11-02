import UIKit
struct BackgroundDefinition: Codable { let id: String, pack: String, title: String, image: String, thumbnail: String }
final class BackgroundChooserController: UIViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let values:[BackgroundDefinition],select:(BackgroundDefinition?)->Void,close:()->Void,actions:[()->Void],resolve:(String)->URL?
    private var groups:[String]=[],group="@custom"
    private let table=UITableView(frame:.zero,style:.plain)
    private var collection:UICollectionView!
    private var visible:[BackgroundDefinition] {values.filter{$0.pack==group}}
    init(values:[BackgroundDefinition],select:@escaping(BackgroundDefinition?)->Void,close:@escaping()->Void,actions:[()->Void],resolve:@escaping(String)->URL?) {
        self.values=values;self.select=select;self.close=close;self.actions=actions;self.resolve=resolve;super.init(nibName:nil,bundle:nil)
        let preferred=["@custom","sea","space","common","mountain","desert","forest","jungle","town"]
        let present=Set(values.map(\.pack));groups=preferred.filter{$0=="@custom" || present.contains($0)}+present.subtracting(Set(preferred)).sorted()
    }
    required init?(coder:NSCoder){fatalError()}
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor=UIColor.black.withAlphaComponent(0.65);view.accessibilityIdentifier="BackgroundChooser"
        let dialog=UIView();dialog.backgroundColor = .original(0x444444);dialog.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(dialog)
        table.backgroundColor = .original(0x242a31);table.separatorStyle = .none;table.dataSource=self;table.delegate=self;table.rowHeight=50;table.translatesAutoresizingMaskIntoConstraints=false;dialog.addSubview(table)
        let flow=UICollectionViewFlowLayout();flow.minimumInteritemSpacing=0;flow.minimumLineSpacing=0
        collection=UICollectionView(frame:.zero,collectionViewLayout:flow);collection.backgroundColor = .original(0x444444);collection.register(UICollectionViewCell.self,forCellWithReuseIdentifier:"bg");collection.dataSource=self;collection.delegate=self;collection.translatesAutoresizingMaskIntoConstraints=false;dialog.addSubview(collection)
        let exit=UIButton(type:.system);exit.setTitle("×",for:.normal);exit.tintColor = .white;exit.accessibilityLabel="Закрыть фоны";exit.addAction(UIAction{[weak self] _ in self?.close()},for:.touchUpInside);exit.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(exit)
        NSLayoutConstraint.activate([dialog.centerXAnchor.constraint(equalTo:view.centerXAnchor),dialog.centerYAnchor.constraint(equalTo:view.centerYAnchor),dialog.widthAnchor.constraint(equalToConstant:min(480,view.bounds.width-40)),dialog.heightAnchor.constraint(equalToConstant:min(454,view.bounds.height-40)),table.leadingAnchor.constraint(equalTo:dialog.leadingAnchor),table.topAnchor.constraint(equalTo:dialog.topAnchor),table.bottomAnchor.constraint(equalTo:dialog.bottomAnchor),table.widthAnchor.constraint(equalTo:dialog.widthAnchor,multiplier:0.5),collection.leadingAnchor.constraint(equalTo:table.trailingAnchor),collection.trailingAnchor.constraint(equalTo:dialog.trailingAnchor),collection.topAnchor.constraint(equalTo:dialog.topAnchor),collection.bottomAnchor.constraint(equalTo:dialog.bottomAnchor),exit.trailingAnchor.constraint(equalTo:dialog.trailingAnchor),exit.bottomAnchor.constraint(equalTo:dialog.topAnchor),exit.widthAnchor.constraint(equalToConstant:32),exit.heightAnchor.constraint(equalToConstant:25)])
    }
    func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int{groups.count+3}
    func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let cell=UITableViewCell(style:.default,reuseIdentifier:nil);cell.textLabel?.font=UIFont(name:"Roboto-Regular",size:14)
        if indexPath.row<3 {
            cell.textLabel?.text=["Выбрать цвет","Выбрать изображение","Рисовать"][indexPath.row];cell.backgroundColor=UIColor.original([0x8ac926,0x38bdf8,0xf59e0b][indexPath.row]);cell.textLabel?.textColor=UIColor.original([0x17230c,0x07233a,0x382100][indexPath.row]);cell.accessibilityIdentifier=["background-color","background-image","background-draw"][indexPath.row]
        } else {
            let id=groups[indexPath.row-3]
            let titles=["@custom":"Свои","sea":"Море","space":"Космос","common":"Старые","mountain":"Горы","desert":"Пустыня","forest":"Лес","jungle":"Джунгли","town":"Город"]
            cell.textLabel?.text=titles[id] ?? id;cell.textLabel?.textColor=id==group ? .white:.original(0xb9c1c9);cell.backgroundColor=id==group ? .original(0x59636e):.original(0x242a31)
            cell.imageView?.image=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/dir2.png").path)?.resizedIcon(density:2).withRenderingMode(.alwaysTemplate);cell.tintColor=id==group ? .white:.original(0xb9c1c9);cell.accessibilityIdentifier="background-pack-"+id
        };return cell
    }
    func tableView(_ tableView:UITableView,didSelectRowAt indexPath:IndexPath){if indexPath.row<3 {actions[indexPath.row]();return};group=groups[indexPath.row-3];table.reloadData();collection.reloadData();collection.setContentOffset(.zero,animated:false)}
    func collectionView(_ collectionView:UICollectionView,numberOfItemsInSection section:Int)->Int{visible.count}
    func collectionView(_ collectionView:UICollectionView,layout collectionViewLayout:UICollectionViewLayout,sizeForItemAt indexPath:IndexPath)->CGSize{CGSize(width:90,height:90)}
    func collectionView(_ collectionView:UICollectionView,cellForItemAt indexPath:IndexPath)->UICollectionViewCell{
        let cell=collectionView.dequeueReusableCell(withReuseIdentifier:"bg",for:indexPath);cell.contentView.subviews.forEach{$0.removeFromSuperview()};let value=visible[indexPath.item]
        let image=UIImageView(frame:CGRect(x:0,y:0,width:90,height:90));image.contentMode = .scaleAspectFit;image.image=resolve(value.thumbnail).flatMap{UIImage(contentsOfFile:$0.path)};cell.contentView.addSubview(image);cell.isAccessibilityElement=true;cell.accessibilityLabel=value.title;cell.accessibilityIdentifier="background-"+value.id;return cell
    }
    func collectionView(_ collectionView:UICollectionView,didSelectItemAt indexPath:IndexPath){select(visible[indexPath.item])}
}

private enum BackgroundAssets {
    static let definitions: [BackgroundDefinition] = {
        guard let url=Bundle.main.resourceURL?.appendingPathComponent("Content/backgrounds.json"),let data=try? Data(contentsOf:url) else{return []}
        return (try? JSONDecoder().decode([BackgroundDefinition].self,from:data)) ?? []
    }()
    static let cache: NSCache<NSString,UIImage> = {let cache=NSCache<NSString,UIImage>();cache.countLimit=3;cache.totalCostLimit=64*1024*1024;return cache}()
    static func image(_ definition: BackgroundDefinition) -> UIImage? {
        if let image=cache.object(forKey:definition.id as NSString){return image}
        guard let url=Bundle.main.resourceURL?.appendingPathComponent("Content/"+definition.image),let image=UIImage(contentsOfFile:url.path) else{return nil}
        let cost=(image.cgImage?.bytesPerRow ?? 0)*(image.cgImage?.height ?? 0)
        cache.setObject(image,forKey:definition.id as NSString,cost:cost);return image
    }
}
extension Workspace {var backgroundCatalog: [BackgroundDefinition] {BackgroundAssets.definitions+UserBackgroundLibrary.list(in:directory)}}
extension SceneCanvas {
    func paintBackground(_ frame: SceneFrame, in context: CGContext) {
        if let raw=frame.attributes["nativeBackgroundColor"] {
            let values=raw.split(separator:",").compactMap{Double($0)}
            if values.count==4 {UIColor(red:values[0],green:values[1],blue:values[2],alpha:values[3]).setFill();context.fill(CGRect(x:0,y:0,width:workspace.document.width,height:workspace.document.height))}
        }
        let selectedImage:UIImage?
        if let custom=frame.attributes["nativeBackgroundImage"] {selectedImage=image(custom)}
        else if let id=frame.attributes["nativeBackgroundID"],let definition=workspace.backgroundCatalog.first(where:{$0.id==id}) {selectedImage=definition.image.hasPrefix("@local/") ? image(definition.image):BackgroundAssets.image(definition)}
        else {selectedImage=nil}
        guard let image=selectedImage else{return}
        let area = CGSize(width: workspace.document.width, height: workspace.document.height)
        let scale = max(area.width / image.size.width, area.height / image.size.height)
        image.draw(in: CGRect(x: (area.width - image.size.width * scale) / 2, y: (area.height - image.size.height * scale) / 2, width: image.size.width * scale, height: image.size.height * scale))
    }
}
