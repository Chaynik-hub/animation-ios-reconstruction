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
        apply.addAction(UIAction { [weak self] _ in self?.chooseEasing() }, for: .touchUpInside)
        let title = UILabel()
        title.text = "Tween"
        title.textColor = .white
        firstLabel.textColor = .white
        lastLabel.textColor = .white
        let controls = UIStackView(arrangedSubviews: [title, firstLabel, first, lastLabel, last, apply, close])
        controls.axis = .vertical
        controls.distribution = .fillEqually
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)
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

    private func chooseEasing() {
        let picker = TweenCurvePicker { [weak self] curve, strength, frequency in
            self?.applyTween(curve: curve, strength: strength, frequency: frequency)
        }
        picker.modalPresentationStyle = .overFullScreen
        present(picker, animated: false)
    }

    private func applyTween(curve: TweenCurve, strength: Double, frequency: Double) {
        let a = min(Int(first.value), Int(last.value)), b = max(Int(first.value), Int(last.value))
        guard b - a >= 2, unit(in: a) != nil, unit(in: b) != nil else { return }
        var document = workspace.document
        let firstFrame = document.frames[a], lastFrame = document.frames[b]
        func assembly(_ frame: SceneFrame) -> [SceneUnit] {
            guard let root = frame.units.first(where: { $0.name == unitName }) else { return [] }
            var result = [root], visited = Set([root.name]), cursor = 0
            while cursor < result.count {
                let parent = result[cursor].name
                cursor += 1
                for unit in frame.units where FrameManipulation.attachment(unit)?.0 == parent {
                    if visited.insert(unit.name).inserted { result.append(unit) }
                }
            }
            return result
        }
        do {
            let startUnits = assembly(firstFrame), endUnits = assembly(lastFrame)
            guard Set(startUnits.map(\.name)) == Set(endUnits.map(\.name)) else { throw PoseError.incompatibleTopology }
            for item in startUnits {
                let firstLink = FrameManipulation.attachment(item)
                let lastLink = endUnits.first(where: { $0.name == item.name }).flatMap(FrameManipulation.attachment)
                guard firstLink?.0 == lastLink?.0, firstLink?.1 == lastLink?.1 else { throw PoseError.incompatibleTopology }
            }
            for index in (a + 1)..<b {
                let fraction = Double(index - a) / Double(b - a)
                let existing = assembly(document.frames[index])
                guard Set(existing.map(\.name)).isSubset(of: Set(startUnits.map(\.name))) else {
                    throw PoseError.incompatibleTopology
                }
                for first in startUnits {
                    guard let last = endUnits.first(where: { $0.name == first.name }) else { throw PoseError.incompatibleTopology }
                    let pose = try curve.pose(from: first, to: last, at: fraction, strength: strength, frequency: frequency)
                    if let target = document.frames[index].units.firstIndex(where: { $0.name == first.name }) {
                        let expected = FrameManipulation.attachment(first)
                        let actual = FrameManipulation.attachment(document.frames[index].units[target])
                        guard expected?.0 == actual?.0, expected?.1 == actual?.1,
                              FrameManipulation.pastePose(pose, into: &document.frames[index], unitIndex: target)
                        else { throw PoseError.incompatibleTopology }
                        document.frames[index].units[target].attributes["alpha"] = pose.attributes["alpha"]
                    } else {
                        document.frames[index].units.append(pose)
                        let target = document.frames[index].units.count - 1
                        guard FrameManipulation.pastePose(pose, into: &document.frames[index], unitIndex: target)
                        else { throw PoseError.incompatibleTopology }
                    }
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
