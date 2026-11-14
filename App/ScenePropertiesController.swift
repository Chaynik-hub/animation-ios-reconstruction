import UIKit

final class ScenePropertiesController: UIViewController {
    private struct Preset {
        let title: String
        let size: CGSize
        init(_ title: String, _ width: Int, _ height: Int) {
            self.title = title
            size = CGSize(width: width, height: height)
        }
    }

    private let workspace: Workspace
    private var size: CGSize
    private let sizeButton = UIButton(type: .system)
    private let speed = UISlider()
    private let hold = UISlider()
    private let speedLabel = UILabel()
    private let smoothing = UIButton(type: .system)
    private var withoutInterpolation: Bool
    private var presets: [Preset] = []

    init(workspace: Workspace) {
        self.workspace = workspace
        size = CGSize(width: workspace.document.width, height: workspace.document.height)
        withoutInterpolation = workspace.document.attributes["no_interpolation"] == "true"
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.60)
        let screen = view.window?.screen.bounds.size ?? UIScreen.main.bounds.size
        let wide = Int(max(screen.width, screen.height))
        let tall = Int(min(screen.width, screen.height))
        presets = [Preset("По умолчанию", wide, tall), Preset("Малый (ландшафт)", 320, 240),
                   Preset("Средний (ландшафт)", 480, 320), Preset("Большой (ландшафт)", 640, 480),
                   Preset("Весь экран", wide, tall), Preset("HD Ready", 1280, 720),
                   Preset("Portrait 9:16 HD", 720, 1280), Preset("Portrait 9:16 Full HD", 1080, 1920),
                   Preset("Portrait 4:5", 1080, 1350), Preset("Portrait 3:4", 1080, 1440)]

        let title = UILabel()
        title.text = "Параметры сцены"
        title.font = UIFont(name: "Roboto-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        title.textColor = .white

        sizeButton.contentHorizontalAlignment = .leading
        sizeButton.addAction(UIAction { [weak self] _ in self?.chooseSize() }, for: .touchUpInside)
        sizeButton.accessibilityLabel = "Размер сцены"
        let plus = UIButton(type: .system)
        plus.setImage(UIImage(systemName: "plus"), for: .normal)
        plus.accessibilityLabel = "Свой размер"
        plus.widthAnchor.constraint(equalToConstant: 44).isActive = true
        plus.addAction(UIAction { [weak self] _ in self?.customSize() }, for: .touchUpInside)
        let sizes = UIStackView(arrangedSubviews: [sizeButton, plus])

        speedLabel.textColor = .white
        speedLabel.font = UIFont(name: "Roboto-Regular", size: 16) ?? .systemFont(ofSize: 16)
        speed.maximumValue = Float(max(48, workspace.document.interframes))
        speed.value = Float(workspace.document.interframes)
        speed.accessibilityLabel = "Промежуточные кадры"
        hold.maximumValue = 9
        hold.value = Float(workspace.document.attributes["no_interpolation_frames"].flatMap(Int.init) ?? 0)
        hold.accessibilityLabel = "Задержка кадра"
        for slider in [speed, hold] {
            slider.minimumTrackTintColor = .original(0x00bd78)
            slider.addTarget(self, action: #selector(updateSlider(_:)), for: .valueChanged)
        }
        smoothing.contentHorizontalAlignment = .leading
        smoothing.setTitle("Без сглаживания", for: .normal)
        smoothing.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.withoutInterpolation.toggle()
            self.refresh()
        }, for: .touchUpInside)

        let cancel = UIButton(type: .system)
        cancel.setTitle("ОТМЕНА", for: .normal)
        cancel.addAction(UIAction { [weak self] _ in self?.dismiss(animated: false) }, for: .touchUpInside)
        let done = UIButton(type: .system)
        done.setTitle("OK", for: .normal)
        done.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [UIView(), cancel, done])
        actions.distribution = .fillEqually
        let panel = UIStackView(arrangedSubviews: [title, sizes, speedLabel, speed, smoothing, hold, actions])
        panel.axis = .vertical
        panel.spacing = 6
        panel.backgroundColor = .original(0x303030)
        panel.tintColor = .original(0x00bd78)
        panel.isLayoutMarginsRelativeArrangement = true
        panel.layoutMargins = UIEdgeInsets(top: 14, left: 20, bottom: 10, right: 20)
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        let width = panel.widthAnchor.constraint(equalToConstant: 400)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            width,
            panel.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, constant: -24),
            panel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
        refresh()
    }

    private func dimensions(_ size: CGSize) -> String {
        "\(Int(size.width)) × \(Int(size.height))"
    }

    private func refresh() {
        let caption = presets.first(where: { $0.size == size })?.title
        let value = caption.map { "\($0) · \(dimensions(size))" } ?? dimensions(size)
        sizeButton.setTitle(value + "  ▾", for: .normal)
        sizeButton.accessibilityValue = value
        speedLabel.text = "Скорость анимации · \(Int(speed.value)) пром. кадров"
        smoothing.setImage(UIImage(systemName: withoutInterpolation ? "checkmark.square" : "square"), for: .normal)
        smoothing.accessibilityValue = withoutInterpolation ? "Вкл." : "Выкл."
        hold.isHidden = !withoutInterpolation
        hold.accessibilityValue = String(Int(hold.value))
    }

    @objc private func updateSlider(_ slider: UISlider) {
        slider.value = slider.value.rounded()
        refresh()
    }

    private func chooseSize() {
        let alert = UIAlertController(title: "Размер сцены", message: nil, preferredStyle: .actionSheet)
        for preset in presets {
            alert.addAction(UIAlertAction(title: "\(preset.title) · \(dimensions(preset.size))", style: .default) { [weak self] _ in
                self?.size = preset.size
                self?.refresh()
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.popoverPresentationController?.sourceView = sizeButton
        alert.popoverPresentationController?.sourceRect = sizeButton.bounds
        present(alert, animated: true)
    }

    private func customSize() {
        let alert = UIAlertController(title: "Размер сцены", message: nil, preferredStyle: .alert)
        for (label, value) in [("Ширина", size.width), ("Высота", size.height)] {
            alert.addTextField { field in
                field.placeholder = label
                field.accessibilityLabel = label
                field.keyboardType = .numberPad
                field.text = String(Int(value))
            }
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak alert] _ in
            guard let self, let fields = alert?.textFields,
                  let w = Int(fields[0].text ?? ""), let h = Int(fields[1].text ?? ""),
                  (1...4096).contains(w), (1...4096).contains(h) else { return }
            self.size = CGSize(width: w, height: h)
            self.refresh()
        })
        present(alert, animated: true)
    }

    private func save() {
        var updated = workspace.document
        updated.width = size.width
        updated.height = size.height
        updated.interframes = Int(speed.value)
        updated.attributes["no_interpolation"] = withoutInterpolation ? "true" : nil
        updated.attributes["no_interpolation_frames"] = withoutInterpolation ? String(Int(hold.value)) : nil
        if updated != workspace.document {
            workspace.checkpoint()
            workspace.document = updated
            workspace.notify()
        }
        dismiss(animated: false)
    }
}
