import UIKit

struct CatalogPack: Decodable {
    let id: String
    let title: String
    let titles: [String: String]?
    let thumbnail: String?
    var displayTitle: String {
        let language = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
        return titles?[language] ?? titles?["en"] ?? title
    }
}

final class CatalogController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    enum Entry { case pack(CatalogPack), folder(String), item(ArtworkDefinition), mySprites }
    var assets: [ArtworkDefinition]
    let pick: (ArtworkDefinition) -> Void
    let resolve: (String) -> URL?
    let close: () -> Void
    let importATI: () -> Void
    private var showingUserSprites=false
    private let importButton=UIButton(type:.system)
    private var importHeight:NSLayoutConstraint!
    private var packs: [CatalogPack] = []
    private var pack: CatalogPack?
    private var path: [String] = []
    private var entries: [Entry] = []
    private var collection: UICollectionView!
    private let back = UIButton(type: .system)
    private let caption = UILabel()
    init(_ assets: [ArtworkDefinition], resolve: @escaping (String) -> URL?, close: @escaping () -> Void, importATI: @escaping () -> Void, pick: @escaping (ArtworkDefinition) -> Void) {
        self.assets = assets; self.resolve = resolve; self.close = close; self.pick = pick; self.importATI=importATI
        super.init(nibName: nil, bundle: nil)
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Content/packs.json"), let data = try? Data(contentsOf: url) {
            packs = (try? JSONDecoder().decode([CatalogPack].self, from: data)) ?? []
        }
        let known = Set(packs.map(\.id))
        for id in Set(assets.map { $0.packID ?? String($0.name.split(separator: ":").first ?? "") }).sorted() where !known.contains(id) && id != "@user" {
            packs.append(CatalogPack(id: id, title: id == "@" ? "Мои объекты" : id, titles: nil, thumbnail: nil))
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .original(0xa5e93f); view.accessibilityIdentifier = "CatalogPanel"
        let header = UIView(); header.backgroundColor = .original(0x212121); header.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(header)
        back.setTitle("‹", for: .normal); back.titleLabel?.font = .systemFont(ofSize: 28); back.tintColor = .white
        back.accessibilityLabel = "Назад по каталогу"; back.addAction(UIAction { [weak self] _ in self?.goBack() }, for: .touchUpInside)
        let exit = UIButton(type: .system); exit.setTitle("×", for: .normal); exit.titleLabel?.font = .systemFont(ofSize: 25); exit.tintColor = .white
        exit.accessibilityLabel = "Закрыть каталог"; exit.addAction(UIAction { [weak self] _ in self?.close() }, for: .touchUpInside)
        caption.font = UIFont(name: "Roboto-Regular", size: 12); caption.textColor = .white; caption.textAlignment = .center
        let bar = UIStackView(arrangedSubviews: [back, caption, exit]); bar.translatesAutoresizingMaskIntoConstraints = false; header.addSubview(bar)
        let layout = UICollectionViewFlowLayout(); layout.minimumLineSpacing = 5
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout); collection.translatesAutoresizingMaskIntoConstraints = false
        collection.backgroundColor = .original(0x212121); collection.dataSource = self; collection.delegate = self
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "entry"); view.addSubview(collection)
        importButton.translatesAutoresizingMaskIntoConstraints=false;importButton.setTitle("Добавить .ati",for:.normal);importButton.tintColor = .white;importButton.backgroundColor = .original(0x34343f);importButton.accessibilityIdentifier="ATIImport";importButton.addAction(UIAction{[weak self] _ in self?.importATI()},for:.touchUpInside);view.addSubview(importButton)
        importHeight=importButton.heightAnchor.constraint(equalToConstant:0)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4), header.trailingAnchor.constraint(equalTo: view.trailingAnchor), header.topAnchor.constraint(equalTo: view.topAnchor), header.heightAnchor.constraint(equalToConstant: 36),
            bar.leadingAnchor.constraint(equalTo: header.leadingAnchor), bar.trailingAnchor.constraint(equalTo: header.trailingAnchor), bar.topAnchor.constraint(equalTo: header.topAnchor), bar.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            back.widthAnchor.constraint(equalToConstant: 32), exit.widthAnchor.constraint(equalToConstant: 32),
            collection.leadingAnchor.constraint(equalTo: header.leadingAnchor), collection.trailingAnchor.constraint(equalTo: view.trailingAnchor), collection.topAnchor.constraint(equalTo: header.bottomAnchor), collection.bottomAnchor.constraint(equalTo: importButton.topAnchor),importButton.leadingAnchor.constraint(equalTo:header.leadingAnchor),importButton.trailingAnchor.constraint(equalTo:view.trailingAnchor),importButton.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor),importHeight
        ]); reload()
    }
    func updateAssets(_ values:[ArtworkDefinition]) {assets=values;if isViewLoaded{reload()}}
    private func reload() {
        importButton.isHidden = !showingUserSprites;importHeight.constant=showingUserSprites ? 50:0
        if showingUserSprites {
            entries=assets.filter{$0.packID=="@user"}.sorted{$0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending}.map(Entry.item)
            caption.text="Мои спрайты";back.isHidden=false
        } else if let pack {
            let matching = assets.filter { ($0.packID ?? String($0.name.split(separator: ":").first ?? "")) == pack.id }
            let descendants = matching.filter { Array(($0.folderPath ?? []).prefix(path.count)) == path }
            let folders = Set(descendants.compactMap { item -> String? in let folders = item.folderPath ?? []; return folders.count > path.count ? folders[path.count] : nil }).sorted()
            let items = descendants.filter { ($0.folderPath ?? []) == path }.sorted { ($0.catalogOrder ?? Int.max, $0.name) < ($1.catalogOrder ?? Int.max, $1.name) }
            entries = (path.isEmpty ? [.mySprites]:[]) + folders.map(Entry.folder) + items.map(Entry.item)
            caption.text = path.last ?? pack.displayTitle; back.isHidden = false
        } else { entries = packs.map(Entry.pack); caption.text = "Наборы"; back.isHidden = true }
        collection.backgroundColor = .original(0x202020)
        collection.reloadData(); collection.setContentOffset(.zero, animated: false)
    }
    private func goBack() { if showingUserSprites {showingUserSprites=false} else if !path.isEmpty { path.removeLast() } else { pack = nil }; reload() }
    override func accessibilityPerformEscape() -> Bool { if pack != nil { goBack() } else { close() }; return true }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { entries.count }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height: CGFloat
        switch entries[indexPath.item] { case .pack: height = 191; case .folder, .mySprites: height = 50; case .item: height = 60 }
        return CGSize(width: collectionView.bounds.width, height: height)
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "entry", for: indexPath); cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        let image = UIImageView(); image.contentMode = .scaleAspectFit
        let label = UILabel(); label.font = UIFont(name: "Roboto-Regular", size: 14); label.numberOfLines = 2
        var imagePath: String?
        switch entries[indexPath.item] {
        case .pack(let value):
            cell.contentView.backgroundColor = .white; image.frame = CGRect(x: 6, y: 6, width: cell.bounds.width - 12, height: 150)
            label.frame = CGRect(x: 5, y: 157, width: cell.bounds.width - 10, height: 30); label.textAlignment = .center; label.textColor = .original(0x212121)
            label.text = value.displayTitle; imagePath = value.thumbnail; cell.accessibilityIdentifier = "catalog-pack-" + value.id
        case .mySprites:
            cell.contentView.backgroundColor = .original(0xfff7df);image.frame=CGRect(x:10,y:5,width:40,height:40);image.image=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/dir2.png").path)
            label.frame=CGRect(x:55,y:0,width:cell.bounds.width-60,height:50);label.text="Мои спрайты";label.textColor = .original(0xac812b);cell.accessibilityIdentifier="catalog-my-sprites"
        case .folder(let value):
            cell.contentView.backgroundColor = .original(0xfff7df); image.frame = CGRect(x: 10, y: 5, width: 40, height: 40)
            image.image = UIImage(contentsOfFile: Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/dir2.png").path)
            label.frame = CGRect(x: 55, y: 0, width: cell.bounds.width - 60, height: 50); label.text = value; label.textColor = .original(0xac812b)
            cell.accessibilityIdentifier = "catalog-folder-" + value
        case .item(let value):
            cell.contentView.backgroundColor = .clear; image.backgroundColor = .original(0xffcdcd); image.frame = CGRect(x: 10, y: 5, width: 50, height: 50)
            label.frame = CGRect(x: 65, y: 0, width: cell.bounds.width - 70, height: 60); label.text = value.displayTitle; label.textColor = .white; imagePath = value.thumbnail
            let corner = UIImageView(frame: CGRect(x: cell.bounds.width - 12, y: 0, width: 12, height: 12))
            corner.image = Bundle.main.resourceURL.flatMap {
                UIImage(contentsOfFile: $0.appendingPathComponent("Content/Icons/catalog_long_press.png").path)
            }
            cell.contentView.addSubview(corner)
            cell.accessibilityIdentifier = "catalog-item-" + value.name
        }
        if let imagePath, let url = resolve(imagePath) { image.image = UIImage(contentsOfFile: url.path) }
        cell.contentView.addSubview(image); cell.contentView.addSubview(label); cell.isAccessibilityElement = true; cell.accessibilityLabel = label.text
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch entries[indexPath.item] { case .mySprites: showingUserSprites=true;reload(); case .pack(let value): pack = value; path = []; showingUserSprites=false;reload(); case .folder(let value): path.append(value); reload(); case .item(let value): pick(value) }
    }
}
