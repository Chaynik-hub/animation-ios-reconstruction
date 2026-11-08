import UIKit
import UniformTypeIdentifiers
import AVFoundation

final class LandingController: UIViewController, UIDocumentPickerDelegate {
    private let panel = UIView()
    private let rail = UIStackView()
    private let projects = UIScrollView()
    private let projectGrid = UIStackView()
    private let separator = UIView()
    private let version = UILabel()
    private let empty = UILabel()
    private var tabs: [UIButton] = []
    private var showingProjects = false
    private var online: CommunityController?
    private var settingsPanel: SettingsController?
    private var toast: UILabel?
    private var projectFiles: [URL] = []
    private let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private lazy var cartoon = artworkButton("Новый\nМультфильм", "landing_hex2", pressed: "landing_hex_pressed2", color: .original(0x6cae00), size: 16) { [weak self] in self?.openEditor() }
    private lazy var items = artworkButton("Конструктор\nпредметов", "landing_hex_items", pressed: "landing_hex_items_pressed", color: .original(0x00b6ff), size: 12) { [weak self] in self?.soon() }
    private lazy var community = artworkButton("Дискорд", "landing_community", color: .original(0xf5c8ff), size: 12) { [weak self] in self?.soon() }
    private lazy var settings = artworkButton("", "cog", color: .white, size: 12) { [weak self] in self?.showSettings() }
    private lazy var onlineButton = textButton("Онлайн", size: 14) { [weak self] in self?.showOnline() }
    private lazy var importButton = textButton("Открыть из файлов", size: 14) { [weak self] in self?.importProject() }

    override var prefersStatusBarHidden: Bool { AnimationSettings.bool("fullScreen",fallback:true) }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    private let landingBackdrop = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "LandingScreen"
        view.backgroundColor = .original(0x3d3e4c)
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Content/Icons/landing_background.png") {
            landingBackdrop.image = UIImage(contentsOfFile: url.path)
        }
        landingBackdrop.alpha = 0.3
        landingBackdrop.contentMode = .scaleAspectFit
        view.addSubview(landingBackdrop)
        view.addSubview(panel)
        view.addSubview(rail)
        rail.axis = .vertical
        rail.distribution = .fillEqually
        rail.spacing = 10
        rail.isLayoutMarginsRelativeArrangement = true
        rail.layoutMargins = UIEdgeInsets(top: 15, left: 8, bottom: 15, right: 8)
        rail.backgroundColor = .original(0x24252f)
        let make = textButton("СОЗДАТЬ", size: 14) { [weak self] in self?.selectProjects(false) }
        let load = textButton("ЗАГРУЗИТЬ", size: 14) { [weak self] in self?.selectProjects(true) }
        load.accessibilityLabel = "Проекты"
        load.accessibilityIdentifier = "LandingProjects"
        let watch = textButton("СМОТРЕТЬ", size: 14) { [weak self] in self?.soon() }
        tabs = [make, load, watch]
        tabs.forEach { rail.addArrangedSubview($0) }
        version.text = "Рисуем мультфильмы 2"
        version.font = font(14)
        version.textColor = .original(0xaaaaaa)
        empty.text = "Нет сохранённых проектов"
        empty.textColor = .white
        empty.textAlignment = .center
        empty.font = font(14)
        separator.backgroundColor = UIColor.white.withAlphaComponent(0.65)
        projectGrid.axis = .vertical
        projectGrid.spacing = 1
        projects.addSubview(projectGrid)
        settings.accessibilityLabel = "Настройки"
        cartoon.accessibilityIdentifier = "LandingCreateProject"
        [separator, cartoon, items, community, settings, version, projects, importButton, onlineButton, empty].forEach { panel.addSubview($0) }
        selectProjects(false, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadProjects()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        landingBackdrop.frame = view.bounds
        rail.frame = CGRect(x: safe.maxX - 100, y: safe.minY, width: 100, height: safe.height)
        panel.frame = CGRect(x: safe.minX, y: safe.minY, width: max(0, safe.width - 100), height: safe.height)
        let w = panel.bounds.width, h = panel.bounds.height
        let split = w * 0.6
        settings.frame = CGRect(x: 80, y: 0, width: 48, height: 52)
        version.frame = CGRect(x: 136, y: 8, width: max(0, w - 140), height: 21)
        separator.frame = CGRect(x: split, y: h / 2 - 80, width: 1, height: 160)
        cartoon.frame = CGRect(x: max(80, split - 179), y: h / 2 - 94, width: min(170, max(0, split - 82)), height: 188)
        items.frame = CGRect(x: split + 8, y: h * 0.09, width: min(118, w - split - 8), height: 132)
        community.frame = CGRect(x: max(split, w - 137), y: max(0, h - 132), width: 98, height: 116)
        importButton.frame = CGRect(x: 8, y: 8, width: 170, height: 42)
        onlineButton.frame = CGRect(x: 186, y: 8, width: 115, height: 42)
        empty.frame = CGRect(x: 0, y: 60, width: w, height: 48)
        projects.frame = showingProjects ? CGRect(x: 8, y: 58, width: w - 16, height: h - 66) : CGRect(x: 0, y: 8, width: 79, height: h - 16)
        layoutProjects()
        online?.view.frame = projects.frame
        settingsPanel?.view.frame = panel.bounds
        toast?.center = CGPoint(x: safe.midX, y: safe.maxY - 32)
    }

    func showProjects() { selectProjects(true) }

    private func selectProjects(_ show: Bool, animated: Bool = true) {
        removeEmbedded()
        showingProjects = show
        for (index, tab) in tabs.enumerated() {
            tab.backgroundColor = index == (show ? 1 : 0) ? .original(0x354669) : .clear
            tab.accessibilityTraits = index == (show ? 1 : 0) ? [.button, .selected] : .button
        }
        for control in [separator, cartoon, items, community, settings, version] { control.isHidden = show }
        importButton.isHidden = !show
        onlineButton.isHidden = !show
        reloadProjects()
        view.setNeedsLayout()
        if animated && !UIAccessibility.isReduceMotionEnabled {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.2
            panel.layer.add(fade, forKey: "landingPanel")
        }
    }

    private func reloadProjects() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)) ?? []
        projectFiles = files.filter { $0.lastPathComponent.hasSuffix(".animation.json") }.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs == rhs ? $0.lastPathComponent < $1.lastPathComponent : lhs > rhs
        }
        laidOutFiles = []
        if !showingProjects { projectFiles = projectFiles.filter { $0.lastPathComponent == "Autosave.animation.json" } }
        empty.isHidden = !showingProjects || !projectFiles.isEmpty
        view.setNeedsLayout()
    }

    private var laidOutFiles: [URL] = []
    private var laidOutColumns = 0
    private func layoutProjects() {
        let tileWidth: CGFloat = showingProjects ? 160 : 78
        let columns = max(1, Int((projects.bounds.width + 1) / (tileWidth + 1)))
        if laidOutFiles != projectFiles || laidOutColumns != columns || projectGrid.bounds.width != projects.bounds.width {
            laidOutFiles = projectFiles
            laidOutColumns = columns
            projectGrid.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for offset in stride(from: 0, to: projectFiles.count, by: columns) {
                let row = UIStackView()
                row.spacing = 1
                for url in projectFiles[offset..<min(offset + columns, projectFiles.count)] {
                    let autosave = url.lastPathComponent == "Autosave.animation.json"
                    let name = autosave ? "Автосохр." : url.deletingPathExtension().deletingPathExtension().lastPathComponent
                    let tile = textButton(name, size: 12) { [weak self] in self?.openEditor(url) }
                    tile.backgroundColor = .original(0x292b35)
                    tile.layer.cornerRadius = 0
                    tile.widthAnchor.constraint(equalToConstant: tileWidth).isActive = true
                    tile.heightAnchor.constraint(equalToConstant: 64).isActive = true
                    tile.contentVerticalAlignment = .bottom
                    tile.titleEdgeInsets.bottom = 5
                    if let thumbnail = UIImage(contentsOfFile: url.appendingPathExtension("png").path) {
                        tile.setBackgroundImage(thumbnail, for: .normal)
                        tile.titleLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.6)
                    }
                    row.addArrangedSubview(tile)
                }
                row.addArrangedSubview(UIView())
                projectGrid.addArrangedSubview(row)
            }
        }
        let rows = (projectFiles.count + columns - 1) / columns
        projectGrid.frame = CGRect(x: 0, y: 0, width: projects.bounds.width, height: max(0, CGFloat(rows * 65 - 1)))
        projects.contentSize = projectGrid.frame.size
    }

    private func openEditor(_ url: URL? = nil) {
        let editor = EditorController()
        editor.openedFromLanding = true
        editor.loadViewIfNeeded()
        if let url {
            do {
                editor.titleOfScene = try editor.workspace.openEditorProject(url)
            } catch {
                let alert = UIAlertController(title: "Не удалось открыть проект", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
        } else {
            editor.newScene()
        }
        editor.markProjectSaved()
        editor.workspace.history.removeAll()
        editor.workspace.future.removeAll()
        editor.restoreAudio()
        editor.modalPresentationStyle = .fullScreen
        editor.modalTransitionStyle = .crossDissolve
        present(editor, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    private func showOnline() {
        if online != nil {
            removeEmbedded(); projects.isHidden = false; reloadProjects(); onlineButton.setTitle("Онлайн",for:.normal); return
        }
        let feed = CommunityController { [weak self] url, title, preview in
            guard let self else { return }
            do {
                let workspace = Workspace(); workspace.autosaveEnabled = false
                try workspace.load(url)
                if preview {
                    let audio = workspace.document.attributes["nativeAudio"].flatMap { try? AVAudioPlayer(contentsOf: workspace.directory.appendingPathComponent($0)) }
                    self.present(PreviewController(workspace: workspace,audio: audio),animated:false)
                } else {
                    let uniqueTitle = title + " " + UUID().uuidString.prefix(6)
                    let saved = try workspace.save(name: uniqueTitle)
                    self.openEditor(saved)
                }
            } catch { feedError(self,error: error) }
        }
        addChild(feed); panel.addSubview(feed.view); feed.view.frame = projects.frame; feed.didMove(toParent:self)
        online = feed; projects.isHidden = true; empty.isHidden = true
        onlineButton.setTitle("Мои проекты",for:.normal)
    }
    private func removeEmbedded() {
        for controller in [online as UIViewController?, settingsPanel as UIViewController?].compactMap({$0}) {
            controller.willMove(toParent:nil); controller.view.removeFromSuperview(); controller.removeFromParent()
        }
        online = nil; settingsPanel = nil; projects.isHidden = false; onlineButton.setTitle("Онлайн",for:.normal)
    }
    private func showSettings() {
        let controller = SettingsController { [weak self] in self?.selectProjects(false) }
        addChild(controller); panel.addSubview(controller.view); controller.view.frame = panel.bounds; controller.didMove(toParent:self); settingsPanel = controller
    }

    private func importProject() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if presentedViewController === controller {
            controller.dismiss(animated: true) { [weak self] in self?.openEditor(url) }
        } else {
            openEditor(url)
        }
    }

    private func soon() {
        toast?.removeFromSuperview()
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 154, height: 40))
        label.text = "Скоро будет"
        label.textAlignment = .center
        label.font = font(14)
        label.textColor = .white
        label.backgroundColor = .original(0x24252f)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        view.addSubview(label)
        toast = label
        view.setNeedsLayout()
        UIAccessibility.post(notification: .announcement, argument: label.text)
        UIView.animate(withDuration: 0.18, delay: 1.6, options: [], animations: { label.alpha = 0 }) { _ in label.removeFromSuperview() }
    }

    private func textButton(_ title: String, size: CGFloat, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.lightGray, for: .highlighted)
        button.titleLabel?.font = .boldSystemFont(ofSize: size)
        button.layer.cornerRadius = 7
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func artworkButton(_ title: String, _ image: String, pressed: String? = nil, color: UIColor, size: CGFloat, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .custom)
        var config = UIButton.Configuration.plain()
        config.title = title
        config.titleAlignment = .center
        config.imagePlacement = .top
        config.imagePadding = 4
        config.contentInsets = .zero
        config.baseForegroundColor = color
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = UIFont(name: "Roboto-Regular", size: size) ?? .systemFont(ofSize: size)
            return updated
        }
        func icon(_ name: String) -> UIImage? {
            guard let url = Bundle.main.resourceURL?.appendingPathComponent("Content/Landing/\(name).png"),
                  let image = UIImage(contentsOfFile: url.path), let bitmap = image.cgImage else { return nil }
            return UIImage(cgImage: bitmap, scale: name == "cog" ? 3 : 4, orientation: .up).withRenderingMode(.alwaysOriginal)
        }
        let normalImage = icon(image), pressedImage = pressed.flatMap { icon($0) }
        config.image = normalImage
        button.configuration = config
        button.titleLabel?.numberOfLines = 0
        button.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.image = button.isHighlighted ? pressedImage ?? normalImage : normalImage
            button.configuration = config
        }
        button.addAction(UIAction { [weak button] _ in
            if let button, !UIAccessibility.isReduceMotionEnabled {
                let shake = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                shake.values = [0, -Double.pi / 18, Double.pi / 18, 0]
                shake.keyTimes = [0, 0.2, 0.6, 1]
                shake.duration = 0.5
                button.layer.add(shake, forKey: "landingPress")
            }
            action()
        }, for: .touchUpInside)
        return button
    }

    private func font(_ size: CGFloat) -> UIFont {
        UIFont(name: "Roboto-Regular", size: size) ?? .systemFont(ofSize: size)
    }
}

private func feedError(_ controller: UIViewController, error: Error) {
    let alert = UIAlertController(title:"Не удалось открыть проект",message:error.localizedDescription,preferredStyle:.alert)
    alert.addAction(UIAlertAction(title:"OK",style:.default)); controller.present(alert,animated:true)
}
