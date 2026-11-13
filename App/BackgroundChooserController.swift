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
        super.viewDidLoad();view.backgroundColor=UIColor.black.withAlphaComponent(0.60);view.accessibilityIdentifier="BackgroundChooser"
        let dialog=UIView();dialog.backgroundColor = .original(0x3e3e3e);dialog.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(dialog)
        table.backgroundColor = .original(0x242a31);table.separatorStyle = .none;table.dataSource=self;table.delegate=self;table.rowHeight=50;table.translatesAutoresizingMaskIntoConstraints=false;dialog.addSubview(table)
        let flow=UICollectionViewFlowLayout();flow.minimumInteritemSpacing=0;flow.minimumLineSpacing=0
        collection=UICollectionView(frame:.zero,collectionViewLayout:flow);collection.backgroundColor = .original(0x3e3e3e);collection.register(UICollectionViewCell.self,forCellWithReuseIdentifier:"bg");collection.dataSource=self;collection.delegate=self;collection.translatesAutoresizingMaskIntoConstraints=false;dialog.addSubview(collection)
        let backdrop = UIButton(type: .custom)
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.accessibilityLabel = "Закрыть фоны"
        backdrop.addAction(UIAction { [weak self] _ in self?.close() }, for: .touchUpInside)
        view.insertSubview(backdrop, belowSubview: dialog)
        dialog.clipsToBounds = true
        dialog.layer.cornerRadius = 2
        table.contentInsetAdjustmentBehavior = .never
        collection.contentInsetAdjustmentBehavior = .never
        NSLayoutConstraint.activate([dialog.centerXAnchor.constraint(equalTo:view.centerXAnchor),dialog.centerYAnchor.constraint(equalTo:view.centerYAnchor),dialog.widthAnchor.constraint(equalTo:view.safeAreaLayoutGuide.widthAnchor,multiplier:0.8,constant:-32),dialog.heightAnchor.constraint(equalTo:view.safeAreaLayoutGuide.heightAnchor,multiplier:0.90,constant:-32),table.leadingAnchor.constraint(equalTo:dialog.leadingAnchor),table.topAnchor.constraint(equalTo:dialog.topAnchor),table.bottomAnchor.constraint(equalTo:dialog.bottomAnchor),table.widthAnchor.constraint(equalTo:dialog.widthAnchor,multiplier:0.5),collection.leadingAnchor.constraint(equalTo:table.trailingAnchor),collection.trailingAnchor.constraint(equalTo:dialog.trailingAnchor),collection.topAnchor.constraint(equalTo:dialog.topAnchor),collection.bottomAnchor.constraint(equalTo:dialog.bottomAnchor)])
    }
    func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int{groups.count+3}
    func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.textLabel?.font = UIFont(name: "Roboto-Regular", size: 16) ?? .systemFont(ofSize: 16)
        if indexPath.row<3 {
            cell.textLabel?.font = UIFont(name: "Roboto-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
            cell.textLabel?.text=["Выбрать цвет","Выбрать изображение","Рисовать"][indexPath.row];cell.backgroundColor=UIColor.original([0x8ac926,0x38bdf8,0xf59e0b][indexPath.row]);cell.textLabel?.textColor=UIColor.original([0x17230c,0x07233a,0x382100][indexPath.row]);cell.accessibilityIdentifier=["background-color","background-image","background-draw"][indexPath.row]
        } else {
            let id=groups[indexPath.row-3]
            let titles=["@custom":"Созданные","sea":"Море","space":"Космос","common":"Классика","mountain":"Горы","desert":"Пустыня","forest":"Лес","jungle":"Джунгли","town":"Город"]
            cell.backgroundColor = id == group ? .original(0x59636e) : .original(0x242a31)
            let color = id == group ? UIColor.white : .original(0xb9c1c9)
            let icon = resolve("Icons/dir2.png").flatMap { UIImage(contentsOfFile: $0.path) }
            let image = UIImageView(image: icon?.withTintColor(color, renderingMode: .alwaysOriginal))
            image.frame = CGRect(x: 10, y: 5, width: 40, height: 40)
            image.contentMode = .scaleAspectFit
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = titles[id] ?? id.prefix(1).uppercased() + String(id.dropFirst())
            label.font = cell.textLabel?.font
            label.textColor = color
            cell.contentView.addSubview(image)
            cell.contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 55),
                label.trailingAnchor.constraint(lessThanOrEqualTo: cell.contentView.trailingAnchor, constant: -5),
                label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
            cell.accessibilityLabel = label.text
            cell.accessibilityIdentifier = "background-pack-" + id
        };return cell
    }
    func tableView(_ tableView:UITableView,didSelectRowAt indexPath:IndexPath){if indexPath.row<3 {actions[indexPath.row]();return};group=groups[indexPath.row-3];table.reloadData();collection.reloadData();collection.setContentOffset(.zero,animated:false)}
    func collectionView(_ collectionView:UICollectionView,numberOfItemsInSection section:Int)->Int{visible.count}
    func collectionView(_ collectionView:UICollectionView,layout collectionViewLayout:UICollectionViewLayout,sizeForItemAt indexPath:IndexPath)->CGSize {
        let width = collectionView.bounds.width
        return CGSize(width: floor(width / max(1, floor(width / 90))), height: 90)
    }
    func collectionView(_ collectionView:UICollectionView,cellForItemAt indexPath:IndexPath)->UICollectionViewCell{
        let cell=collectionView.dequeueReusableCell(withReuseIdentifier:"bg",for:indexPath);cell.contentView.subviews.forEach{$0.removeFromSuperview()};let value=visible[indexPath.item]
        let image=UIImageView(frame:CGRect(x:(cell.contentView.bounds.width - 90) / 2,y:0,width:90,height:90));image.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin];image.contentMode = .scaleAspectFit;image.image=resolve(value.thumbnail).flatMap{UIImage(contentsOfFile:$0.path)};cell.contentView.addSubview(image);cell.isAccessibilityElement=true;cell.accessibilityLabel=value.title;cell.accessibilityIdentifier="background-"+value.id;return cell
    }
    func collectionView(_ collectionView:UICollectionView,didSelectItemAt indexPath:IndexPath){select(visible[indexPath.item])}
}

private enum BackgroundAssets {
    static let definitions: [BackgroundDefinition] = {
        guard let url=Bundle.main.resourceURL?.appendingPathComponent("Content/backgrounds.json"),let data=try? Data(contentsOf:url) else{return []}
        return (try? JSONDecoder().decode([BackgroundDefinition].self,from:data)) ?? []
    }()
    static let cache: NSCache<NSString,UIImage> = {let cache=NSCache<NSString,UIImage>();cache.countLimit=3;cache.totalCostLimit=64*1024*1024;return cache}()
    static func custom(_ path:String,workspace:Workspace)->UIImage? {
        if let image=cache.object(forKey:path as NSString){return image}
        guard let url=workspace.artworkURL(path),let image=UIImage(contentsOfFile:url.path) else{return nil}
        cache.setObject(image,forKey:path as NSString,cost:(image.cgImage?.bytesPerRow ?? 0)*(image.cgImage?.height ?? 0));return image
    }
    static func image(_ definition: BackgroundDefinition) -> UIImage? {
        if let image=cache.object(forKey:definition.id as NSString){return image}
        guard let url=Bundle.main.resourceURL?.appendingPathComponent("Content/"+definition.image),let image=UIImage(contentsOfFile:url.path) else{return nil}
        let cost=(image.cgImage?.bytesPerRow ?? 0)*(image.cgImage?.height ?? 0)
        cache.setObject(image,forKey:definition.id as NSString,cost:cost);return image
    }
}
extension Workspace {var backgroundCatalog:[BackgroundDefinition] {
    if let cache=backgroundLibraryCache{return cache}
    let values=BackgroundAssets.definitions+UserBackgroundLibrary.list(in:directory);backgroundLibraryCache=values;return values
}}
extension SceneCanvas {
    func frameBackgroundColor(_ frame: SceneFrame) -> UIColor? {
        guard let raw = frame.attributes["nativeBackgroundColor"] else { return nil }
        let values = raw.split(separator: ",").compactMap { Double($0) }
        guard values.count == 4, values.allSatisfy({ $0.isFinite }) else { return nil }
        return UIColor(red: values[0], green: values[1], blue: values[2], alpha: values[3])
    }

    func paintBackground(_ frame: SceneFrame, in context: CGContext) {
        let area = CGSize(width: workspace.document.width, height: workspace.document.height)
        let rect = CGRect(origin: .zero, size: area)
        if let color = frameBackgroundColor(frame) {
            context.setFillColor(color.cgColor)
            context.fill(rect)
        }
        let selectedImage:UIImage?
        if let custom=frame.attributes["nativeBackgroundImage"] {selectedImage=BackgroundAssets.custom(custom,workspace:workspace)}
        else if let id=frame.attributes["nativeBackgroundID"],let definition=workspace.backgroundCatalog.first(where:{$0.id==id}) {selectedImage=definition.image.hasPrefix("@local/") ? BackgroundAssets.custom(definition.image,workspace:workspace):BackgroundAssets.image(definition)}
        else {selectedImage=nil}
        guard let image=selectedImage else{return}
        let move = SceneCamera(frame: frame, background: true)
        let fitWidth = area.width / image.size.width
        let baseScale = frame.attributes["nativeBackgroundFit"] == "width" ? fitWidth : max(fitWidth, area.height / image.size.height)
        let scale = baseScale * move.zoom
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.midX + move.x, y: rect.midY + move.y)
        context.rotate(by: move.rotation)
        image.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        context.restoreGState()
    }
}
