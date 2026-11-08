import UIKit

private struct MotionTemplate: Codable {
    let name: String
    let poses: [SceneUnit]
    let ticksPerFrame: Int
}

private enum MotionLibraryStore {
    static let filename = "MotionLibrary.json"
    static let limit = 16 * 1024 * 1024

    static func load(from directory: URL) -> [MotionTemplate] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(filename)), data.count <= limit else { return [] }
        return (try? JSONDecoder().decode([MotionTemplate].self, from: data)) ?? []
    }

    static func add(_ value: MotionTemplate, to directory: URL) throws {
        let data = try JSONEncoder().encode(load(from: directory) + [value])
        guard data.count <= limit else { throw SceneReadError.resourceLimit }
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
    }
}

extension EditorController {
    func showMotionLibrary(unitName: String?) {
        let units = workspace.frame.units
        let names = unitName.map { [$0] } ?? units.map(\.name)
        guard !names.isEmpty else { message("Библиотека движений", "Сначала добавьте предмет."); return }
        let library = MotionLibraryController(workspace: workspace, names: names)
        library.modalPresentationStyle = .fullScreen
        present(library, animated: true)
    }
}

private final class MotionLibraryController: OriginalListController {
    private let workspace: Workspace
    private let names: [String]
    private let builtIns: [(String, GroundedMotion.Action, Double)] = [
        ("Ходьба", .walk, 2.2), ("Бег", .run, 1.5), ("Прыжок", .jump, 1.35),
        ("Приседание", .crouch, 1.3), ("Удар рукой", .punch, 0.85),
        ("Удар ногой", .kick, 1.0), ("Падение", .fall, 1.1), ("Рэгдолл", .ragdoll, 1.55)
    ]
    override var horizontalContentGuide: UILayoutGuide? { view.safeAreaLayoutGuide }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    init(workspace: Workspace, names: [String]) {
        self.workspace = workspace
        self.names = names
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        if names.count == 1, let name = names.first { showMoves(for: name) }
        else {
            row("‹ Библиотека движений") { [weak self] in self?.dismiss(animated: true) }
            label("Выберите предмет")
            for name in names {
                let base = UnitIdentity.baseName(name)
                row(workspace.artworkByName[base]?.displayTitle ?? name) { [weak self] in self?.showMoves(for: name) }
            }
        }
    }

    private func showMoves(for name: String) {
        clear()
        row("‹ Библиотека движений") { [weak self] in self?.dismiss(animated: true) }
        row("Сохранить своё движение…") { [weak self] in self?.saveTemplate(for: name) }
        label("Готовые движения")
        for (title, action, duration) in builtIns {
            row(title) { [weak self] in self?.chooseDirection(title: title, name: name, action: action, duration: duration) }
        }
        let templates = MotionLibraryStore.load(from: workspace.directory)
        if !templates.isEmpty { label("Мои движения") }
        for template in templates {
            row(template.name) { [weak self] in self?.insertTemplate(template, into: name) }
        }
    }

    private static let recordedFrames: [SceneFrame] = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Content/Reference/cmu-motions.xml"),
              let bytes = try? Data(contentsOf: url),
              let scene = try? SceneXMLReader.read(bytes) else { return [] }
        return scene.frames
    }()

    private func recordedTemplate(_ action: GroundedMotion.Action, direction: Double) -> MotionTemplate? {
        let range: ClosedRange<Int>
        switch action {
        case .walk: range = 4...27
        case .run: range = 34...48
        case .jump: range = 55...71
        case .punch: range = 78...89
        case .kick: range = 96...110
        case .fall: range = 117...132
        case .ragdoll: range = 139...154
        case .crouch: return nil
        }
        let frames = Self.recordedFrames
        guard range.upperBound <= frames.count else { return nil }
        var poses = frames[(range.lowerBound - 1)..<range.upperBound].compactMap { $0.units.first }
        guard poses.count == range.count,
              let first = poses.first?.joints.first(where: { $0.parent == nil }),
              let last = poses.last?.joints.first(where: { $0.parent == nil }) else { return nil }
        let forward = (action == .walk || action == .run) && last.x < first.x ? -1.0 : 1.0
        if direction != forward {
            for index in poses.indices {
                for joint in poses[index].joints.indices {
                    poses[index].joints[joint].x = 2 * first.x - poses[index].joints[joint].x
                }
            }
        }
        return MotionTemplate(name: "", poses: poses, ticksPerFrame: 5)
    }

    private func chooseDirection(title: String, name: String, action: GroundedMotion.Action, duration: Double) {
        guard let unit = workspace.frame.units.first(where: { $0.name == name }) else { return }
        let nativeRig = GroundedMotion(unit: unit)
        let reference = workspace.artworkByName["stickman:stickman"]?.unit(at: .zero)
        guard let rig = nativeRig ?? reference.flatMap({ GroundedMotion(unit: $0) }) else {
            message("Движение недоступно", "В каталоге отсутствует базовый скелет.")
            return
        }
        let retarget = nativeRig == nil ? reference.flatMap { MotionRetarget(source: $0, target: unit) } : nil
        let alert = UIAlertController(title: title, message: "Кадры будут вставлены после текущего.", preferredStyle: .alert)
        for (label, direction) in [("Вправо", 1.0), ("Влево", -1.0)] {
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                guard let self else { return }
                if let recorded = self.recordedTemplate(action, direction: direction) {
                    self.insertTemplate(recorded, into: name)
                    return
                }
                let steps = max(1, Int((duration * 60 / Double(max(1, self.workspace.document.interframes + 1))).rounded()))
                do {
                    let poses = try (1...steps).map { tick in
                        let pose = rig.pose(action, progress: Double(tick) / Double(steps), direction: direction)
                        return try retarget?.pose(pose) ?? pose
                    }
                    self.insert(poses, into: name)
                } catch { self.message("Не удалось перенести движение", "Проверьте структуру скелета предмета.") }
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    private func saveTemplate(for unitName: String) {
        let alert = UIAlertController(title: "Сохранить движение", message: "Укажите первый и последний кадры включительно.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Название движения" }
        alert.addTextField { $0.placeholder = "Первый кадр"; $0.text = "1"; $0.keyboardType = .numbersAndPunctuation }
        alert.addTextField { $0.placeholder = "Последний кадр"; $0.text = String(self.workspace.document.frames.count); $0.keyboardType = .numbersAndPunctuation }
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { [weak self, weak alert] _ in
            guard let self, let fields = alert?.textFields else { return }
            let title = fields[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let frames = self.workspace.document.frames
            guard !title.isEmpty, let first = Int(fields[1].text ?? ""), let last = Int(fields[2].text ?? ""),
                  first >= 1, last > first, last <= frames.count, last - first < 600 else {
                self.message("Не удалось сохранить", "Введите название и диапазон от 2 до 600 кадров.")
                return
            }
            let poses = frames[(first - 1)..<last].compactMap { frame in frame.units.first { $0.name == unitName } }
            guard poses.count == last - first + 1 else {
                self.message("Не удалось сохранить", "Предмет должен присутствовать на каждом кадре диапазона.")
                return
            }
            do {
                try MotionLibraryStore.add(MotionTemplate(name: String(title.prefix(100)), poses: poses,
                                                          ticksPerFrame: max(1, self.workspace.document.interframes + 1)),
                                           to: self.workspace.directory)
                self.showMoves(for: unitName)
            } catch { self.message("Не удалось сохранить", error.localizedDescription) }
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    private func insertTemplate(_ template: MotionTemplate, into name: String) {
        guard let initial = template.poses.first, template.poses.count > 1,
              let target = workspace.frame.units.first(where: { $0.name == name }),
              let retarget = MotionRetarget(source: initial, target: target) else {
            message("Не удалось перенести движение", "У предмета должна быть основная точка.")
            return
        }
        let step = Double(max(1, workspace.document.interframes + 1)) / Double(max(1, template.ticksPerFrame))
        let last = template.poses.count - 1
        let count = max(1, Int(ceil(Double(last) / step)))
        guard count <= 2400 else { message("Слишком длинное движение", "Выберите более короткий диапазон."); return }
        do {
            let poses = try (0...count).map { index -> SceneUnit in
                let position = min(Double(last), Double(index) * step)
                let lower = Int(position)
                let pose = try PoseInterpolation.between(template.poses[lower], template.poses[min(last, lower + 1)],
                                                        progress: position - Double(lower))
                return try retarget.pose(pose)
            }
            insert(poses, into: name, replaceCurrent: true)
        } catch { message("Несовместимый предмет", "Структура скелета менялась внутри шаблона.") }
    }

    private func insert(_ poses: [SceneUnit], into name: String, replaceCurrent: Bool = false) {
        let frame = workspace.frame
        guard let index = frame.units.firstIndex(where: { $0.name == name }), !poses.isEmpty else { return }
        let highest = workspace.document.frames.map(\.id).max() ?? 0
        guard highest <= Int.max - poses.count else { return }
        var frames: [SceneFrame] = []
        for (offset, pose) in poses.enumerated() {
            var output = frame
            output.id = replaceCurrent && offset == 0 ? frame.id : highest + offset + 1
            guard FrameManipulation.pastePose(pose, into: &output, unitIndex: index) else {
                message("Несовместимый предмет", "У шаблона и предмета разные скелеты.")
                return
            }
            frames.append(output)
        }
        workspace.checkpoint()
        if replaceCurrent {
            workspace.document.frames[workspace.index] = frames[0]
            workspace.document.frames.insert(contentsOf: frames.dropFirst(), at: workspace.index + 1)
        } else {
            workspace.document.frames.insert(contentsOf: frames, at: workspace.index + 1)
        }
        workspace.notify()
        dismiss(animated: true)
    }
}
