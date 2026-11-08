import UIKit

extension EditorController {
    func showUnitKinematics() {
        guard let index = workspace.selected, workspace.frame.units.indices.contains(index) else { return }
        let unit = workspace.frame.units[index]
        let base = UnitIdentity.baseName(unit.name)
        let enabled = unit.attributes["nativeKinematicsAllBones"] == "true"
        let sheet = UIAlertController(title: "Дополнительные настройки",
                                      message: "Кинематика для всех костей: " + (enabled ? "включена" : "выключена"),
                                      preferredStyle: .alert)
        sheet.addAction(UIAlertAction(title: enabled ? "Выключить" : "Включить", style: .default) { [weak self] _ in
            guard let self else { return }
            self.workspace.checkpoint()
            for frame in self.workspace.document.frames.indices {
                let units = self.workspace.document.frames[frame].units
                for index in units.indices where UnitIdentity.baseName(units[index].name) == base {
                    self.workspace.document.frames[frame].units[index].attributes["nativeKinematicsAllBones"] = enabled ? nil : "true"
                }
            }
            self.workspace.notify()
        })
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(sheet, animated: true)
    }

    func showUnitTween() {
        guard let index = workspace.selected, workspace.frame.units.indices.contains(index) else { return }
        var root = workspace.frame.units[index]
        var visited = Set<String>()
        while visited.insert(root.name).inserted, let link = FrameManipulation.attachment(root),
              let parent = workspace.frame.units.first(where: { $0.name == link.0 }) {
            root = parent
        }
        let controller = UnitTweenController(workspace: workspace, unitName: root.name)
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }
}

final class UnitTweenController: UIViewController {
    private let workspace: Workspace
    private let unitName: String
    private let preview: SceneCanvas
    private let first = UISlider(), last = UISlider()
    private let firstLabel = UILabel(), lastLabel = UILabel()
    private let apply = UIButton(type: .system)
    private let easing = UISegmentedControl(items: ["Равномерно", "Разгон", "Замедление", "Плавно"])

    init(workspace: Workspace, unitName: String) {
        self.workspace = workspace
        self.unitName = unitName
        preview = SceneCanvas(workspace)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .original(0x242530)
        preview.handles = false
        preview.onion = false
        preview.isUserInteractionEnabled = false
        preview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(preview)
        let close = UIButton(type: .system)
        close.setTitle("Назад", for: .normal)
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        apply.setTitle("Применить", for: .normal)
        apply.addAction(UIAction { [weak self] _ in self?.applyTween() }, for: .touchUpInside)
        let title = UILabel()
        title.text = "Tween"
        title.textColor = .white
        firstLabel.textColor = .white
        lastLabel.textColor = .white
        let controls = UIStackView(arrangedSubviews: [title, firstLabel, first, lastLabel, last, easing, apply, close])
        controls.axis = .vertical
        controls.distribution = .fillEqually
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)
        easing.selectedSegmentIndex = 0
        for slider in [first, last] {
            slider.minimumValue = 0
            slider.maximumValue = Float(workspace.document.frames.count - 1)
            slider.addAction(UIAction { [weak self, weak slider] _ in
                guard let self, let slider else { return }
                self.updatePreview(slider)
            }, for: .valueChanged)
        }
        first.accessibilityLabel = "Начало перехода"
        last.accessibilityLabel = "Конец перехода"
        let indices = workspace.document.frames.indices.filter { unit(in: $0) != nil }
        first.value = Float(indices.last(where: { $0 <= workspace.index }) ?? indices.first ?? 0)
        last.value = Float(indices.last ?? 0)
        let area = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: area.leadingAnchor),
            preview.topAnchor.constraint(equalTo: area.topAnchor),
            preview.bottomAnchor.constraint(equalTo: area.bottomAnchor),
            preview.trailingAnchor.constraint(equalTo: controls.leadingAnchor, constant: -8),
            controls.trailingAnchor.constraint(equalTo: area.trailingAnchor, constant: -12),
            controls.topAnchor.constraint(equalTo: area.topAnchor, constant: 8),
            controls.bottomAnchor.constraint(equalTo: area.bottomAnchor, constant: -8),
            controls.widthAnchor.constraint(equalTo: area.widthAnchor, multiplier: 0.48)
        ])
        updatePreview(first)
    }

    private func unit(in index: Int) -> SceneUnit? {
        workspace.document.frames[index].units.first { $0.name == unitName }
    }

    private func updatePreview(_ slider: UISlider) {
        slider.value = slider.value.rounded()
        let a = Int(first.value), b = Int(last.value)
        firstLabel.text = "Первый кадр: \(a + 1)"
        lastLabel.text = "Последний кадр: \(b + 1)"
        apply.isEnabled = abs(a - b) >= 2 && unit(in: a) != nil && unit(in: b) != nil
        preview.displayed = workspace.document.frames[Int(slider.value)]
        preview.setNeedsDisplay()
    }

    private func applyTween() {
        let a = min(Int(first.value), Int(last.value)), b = max(Int(first.value), Int(last.value))
        guard b - a >= 2, let start = unit(in: a), let end = unit(in: b) else { return }
        var document = workspace.document
        do {
            for index in (a + 1)..<b {
                let fraction = Double(index - a) / Double(b - a)
                let t: Double
                switch easing.selectedSegmentIndex {
                case 1: t = fraction * fraction
                case 2: t = 1 - (1 - fraction) * (1 - fraction)
                case 3: t = fraction * fraction * (3 - 2 * fraction)
                default: t = fraction
                }
                let pose = try PoseInterpolation.between(start, end, progress: t)
                if let target = document.frames[index].units.firstIndex(where: { $0.name == unitName }) {
                    guard FrameManipulation.pastePose(pose, into: &document.frames[index], unitIndex: target)
                    else { throw PoseError.incompatibleTopology }
                    document.frames[index].units[target].attributes["alpha"] = pose.attributes["alpha"]
                } else {
                    document.frames[index].units.append(pose)
                }
            }
        } catch {
            let alert = UIAlertController(title: "Не удалось применить Tween", message: "Проверьте, что скелет предмета совпадает в выбранных кадрах.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        workspace.checkpoint()
        workspace.document = document
        workspace.index = b
        workspace.selected = workspace.frame.units.firstIndex(where: { $0.name == unitName })
        workspace.notify()
        dismiss(animated: true)
    }
}
