import UIKit
struct BackgroundDefinition: Decodable { let id: String, pack: String, title: String, image: String, thumbnail: String }
final class BackgroundChooserController: UIViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let values: [BackgroundDefinition], select: (BackgroundDefinition?) -> Void, close: () -> Void
    private var groups: [String] = [], group = "common"
    private let table = UITableView(frame: .zero, style: .plain)
    private var collection: UICollectionView!
    private var visible: [BackgroundDefinition] { values.filter { $0.pack == group } }
    init(values: [BackgroundDefinition], select: @escaping (BackgroundDefinition?) -> Void, close: @escaping () -> Void) { self.values = values; self.select = select; self.close = close; super.init(nibName: nil, bundle: nil); groups = Array(Set(values.map(\.pack))).sorted(); if !groups.contains(group) { group = groups.first ?? "" } }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .original(0x212121); view.accessibilityIdentifier = "BackgroundChooser"
        let header = UIStackView(); header.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(header)
        let title = UILabel(); title.text = "Фоны"; title.textColor = .white; title.textAlignment = .center; header.addArrangedSubview(title)
        for (name, action) in [("Без фона", { [weak self] in self?.select(nil) }), ("×", { [weak self] in self?.close() })] {
            let button = UIButton(type: .system); button.setTitle(name, for: .normal); button.tintColor = .white; button.accessibilityLabel = name == "×" ? "Закрыть фоны" : name; button.addAction(UIAction { _ in action() }, for: .touchUpInside); header.addArrangedSubview(button)
        }
        table.backgroundColor = .original(0x292929); table.separatorStyle = .none; table.dataSource = self; table.delegate = self; table.rowHeight = 50; table.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(table)
        let flow = UICollectionViewFlowLayout(); flow.minimumInteritemSpacing = 0; flow.minimumLineSpacing = 0
        collection = UICollectionView(frame: .zero, collectionViewLayout: flow); collection.backgroundColor = .original(0x212121); collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "bg"); collection.dataSource = self; collection.delegate = self; collection.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(collection)
        NSLayoutConstraint.activate([header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4), header.trailingAnchor.constraint(equalTo: view.trailingAnchor), header.topAnchor.constraint(equalTo: view.topAnchor), header.heightAnchor.constraint(equalToConstant: 40), table.leadingAnchor.constraint(equalTo: view.leadingAnchor), table.topAnchor.constraint(equalTo: header.bottomAnchor), table.bottomAnchor.constraint(equalTo: view.bottomAnchor), table.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5), collection.leadingAnchor.constraint(equalTo: table.trailingAnchor), collection.trailingAnchor.constraint(equalTo: view.trailingAnchor), collection.topAnchor.constraint(equalTo: header.bottomAnchor), collection.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { groups.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil); cell.textLabel?.text = groups[indexPath.row]; cell.textLabel?.font = UIFont(name: "Roboto-Regular", size: 14); cell.textLabel?.textColor = .original(0xac812b); cell.backgroundColor = groups[indexPath.row] == group ? .original(0x49402d) : .clear
        cell.imageView?.image = UIImage(contentsOfFile: Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/dir2.png").path)?.resizedIcon(density: 2); cell.accessibilityIdentifier = "background-pack-" + groups[indexPath.row]; return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { group = groups[indexPath.row]; table.reloadData(); collection.reloadData(); collection.setContentOffset(.zero, animated: false) }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { visible.count }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize { CGSize(width: min(90, collectionView.bounds.width), height: 90) }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "bg", for: indexPath); cell.contentView.subviews.forEach { $0.removeFromSuperview() }; let value = visible[indexPath.item]
        let image = UIImageView(frame: CGRect(x: 2, y: 2, width: 86, height: 86)); image.contentMode = .scaleAspectFit; image.image = UIImage(contentsOfFile: Bundle.main.resourceURL!.appendingPathComponent("Content/" + value.thumbnail).path); cell.contentView.addSubview(image); cell.isAccessibilityElement = true; cell.accessibilityLabel = value.title; cell.accessibilityIdentifier = "background-" + value.id; return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) { select(visible[indexPath.item]) }
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
extension Workspace {var backgroundCatalog: [BackgroundDefinition] {BackgroundAssets.definitions}}
extension SceneCanvas {
    func paintBackground(_ frame: SceneFrame, in context: CGContext) {
        guard let id = frame.attributes["nativeBackgroundID"], let definition = workspace.backgroundCatalog.first(where: { $0.id == id }), let image = BackgroundAssets.image(definition) else { return }
        let area = CGSize(width: workspace.document.width, height: workspace.document.height)
        let scale = max(area.width / image.size.width, area.height / image.size.height)
        image.draw(in: CGRect(x: (area.width - image.size.width * scale) / 2, y: (area.height - image.size.height * scale) / 2, width: image.size.width * scale, height: image.size.height * scale))
    }
}
