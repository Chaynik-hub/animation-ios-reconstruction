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
    enum Entry { case pack(CatalogPack), folder(String), item(ArtworkDefinition) }
    let assets: [ArtworkDefinition]
    let pick: (ArtworkDefinition) -> Void
    let resolve: (String) -> URL?
    let close: () -> Void
    private var packs: [CatalogPack] = []
    private var pack: CatalogPack?
    private var path: [String] = []
    private var entries: [Entry] = []
    private var collection: UICollectionView!
    private let back = UIButton(type: .system)
    private let caption = UILabel()
    init(_ assets: [ArtworkDefinition], resolve: @escaping (String) -> URL?, close: @escaping () -> Void, pick: @escaping (ArtworkDefinition) -> Void) {
        self.assets = assets; self.resolve = resolve; self.close = close; self.pick = pick
        super.init(nibName: nil, bundle: nil)
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Content/packs.json"), let data = try? Data(contentsOf: url) {
            packs = (try? JSONDecoder().decode([CatalogPack].self, from: data)) ?? []
        }
        let known = Set(packs.map(\.id))
        for id in Set(assets.map { $0.packID ?? String($0.name.split(separator: ":").first ?? "") }).sorted() where !known.contains(id) {
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
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4), header.trailingAnchor.constraint(equalTo: view.trailingAnchor), header.topAnchor.constraint(equalTo: view.topAnchor), header.heightAnchor.constraint(equalToConstant: 36),
            bar.leadingAnchor.constraint(equalTo: header.leadingAnchor), bar.trailingAnchor.constraint(equalTo: header.trailingAnchor), bar.topAnchor.constraint(equalTo: header.topAnchor), bar.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            back.widthAnchor.constraint(equalToConstant: 32), exit.widthAnchor.constraint(equalToConstant: 32),
            collection.leadingAnchor.constraint(equalTo: header.leadingAnchor), collection.trailingAnchor.constraint(equalTo: view.trailingAnchor), collection.topAnchor.constraint(equalTo: header.bottomAnchor), collection.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]); reload()
    }
    private func reload() {
        if let pack {
            let matching = assets.filter { ($0.packID ?? String($0.name.split(separator: ":").first ?? "")) == pack.id }
            let descendants = matching.filter { Array(($0.folderPath ?? []).prefix(path.count)) == path }
            let folders = Set(descendants.compactMap { item -> String? in let folders = item.folderPath ?? []; return folders.count > path.count ? folders[path.count] : nil }).sorted()
            let items = descendants.filter { ($0.folderPath ?? []) == path }.sorted { ($0.catalogOrder ?? Int.max, $0.name) < ($1.catalogOrder ?? Int.max, $1.name) }
            entries = folders.map(Entry.folder) + items.map(Entry.item)
            caption.text = path.last ?? pack.displayTitle; back.isHidden = false
        } else { entries = packs.map(Entry.pack); caption.text = "Наборы"; back.isHidden = true }
        collection.reloadData(); collection.setContentOffset(.zero, animated: false)
    }
    private func goBack() { if !path.isEmpty { path.removeLast() } else { pack = nil }; reload() }
    override func accessibilityPerformEscape() -> Bool { if pack != nil { goBack() } else { close() }; return true }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { entries.count }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height: CGFloat
        switch entries[indexPath.item] { case .pack: height = 191; case .folder: height = 50; case .item: height = 60 }
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
        case .folder(let value):
            cell.contentView.backgroundColor = .original(0x292929); image.frame = CGRect(x: 10, y: 5, width: 40, height: 40)
            image.image = UIImage(contentsOfFile: Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/dir2.png").path)
            label.frame = CGRect(x: 55, y: 0, width: cell.bounds.width - 60, height: 50); label.text = value; label.textColor = .original(0xac812b)
            cell.accessibilityIdentifier = "catalog-folder-" + value
        case .item(let value):
            cell.contentView.backgroundColor = .original(0x212121); image.frame = CGRect(x: 10, y: 5, width: 50, height: 50)
            label.frame = CGRect(x: 65, y: 0, width: cell.bounds.width - 70, height: 60); label.text = value.displayTitle; label.textColor = .white; imagePath = value.thumbnail
            cell.accessibilityIdentifier = "catalog-item-" + value.name
        }
        if let imagePath, let url = resolve(imagePath) { image.image = UIImage(contentsOfFile: url.path) }
        cell.contentView.addSubview(image); cell.contentView.addSubview(label); cell.isAccessibilityElement = true; cell.accessibilityLabel = label.text
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch entries[indexPath.item] { case .pack(let value): pack = value; path = []; reload(); case .folder(let value): path.append(value); reload(); case .item(let value): pick(value) }
    }
}
