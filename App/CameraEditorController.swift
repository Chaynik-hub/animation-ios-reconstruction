import UIKit
import AVFoundation

final class CameraEditorController: UIViewController {
    private let workspace: Workspace
    private let audio: AVAudioPlayer?
    private let canvas: SceneCanvas
    private let navigator = FrameNavigator()
    private var tweenStart: Int?

    init(workspace: Workspace, audio: AVAudioPlayer?) {
        self.workspace = workspace
        self.audio = audio
        canvas = SceneCanvas(workspace)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { AnimationSettings.bool("fullScreen", fallback: true) }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .original(0x242530)
        canvas.cameraEditing = true
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)

        let toolbar = UIStackView(arrangedSubviews: [
            control("Назад", icon: nil) { [weak self] in self?.dismiss(animated: false) },
            control("Сброс", icon: "side_reset") { [weak self] in self?.canvas.resetSceneCamera() },
            control("Отмена", icon: "main_btn_undo_normal") { [weak self] in self?.workspace.undo(); self?.refresh() },
            control("Переход", icon: "side_varspeed") { [weak self] in self?.tween() },
            control("Пуск", icon: "main_btn_play") { [weak self] in
                guard let self else { return }
                self.present(PreviewController(workspace: self.workspace, audio: self.audio), animated: false)
            }
        ])
        toolbar.axis = .vertical
        toolbar.distribution = .fillEqually
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        let previous = control("Предыдущий кадр", icon: "main_prev_frame_np") { [weak self] in
            guard let self else { return }
            self.seek(self.workspace.index - 1)
        }
        let next = control("Следующий кадр", icon: "main_next_frame_np") { [weak self] in
            guard let self else { return }
            self.seek(self.workspace.index + 1)
        }
        previous.heightAnchor.constraint(equalToConstant: 60).isActive = true
        next.heightAnchor.constraint(equalToConstant: 60).isActive = true
        let timeline = UIStackView(arrangedSubviews: [previous, navigator, next])
        timeline.axis = .vertical
        timeline.translatesAutoresizingMaskIntoConstraints = false
        navigator.seek = { [weak self] in self?.seek($0) }
        view.addSubview(timeline)

        let area = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: area.leadingAnchor),
            toolbar.topAnchor.constraint(equalTo: area.topAnchor),
            toolbar.widthAnchor.constraint(equalToConstant: 80),
            toolbar.heightAnchor.constraint(lessThanOrEqualTo: area.heightAnchor),
            toolbar.heightAnchor.constraint(equalTo: area.heightAnchor, multiplier: 0.8),
            timeline.trailingAnchor.constraint(equalTo: area.trailingAnchor),
            timeline.topAnchor.constraint(equalTo: area.topAnchor),
            timeline.bottomAnchor.constraint(equalTo: area.bottomAnchor),
            timeline.widthAnchor.constraint(equalToConstant: 60),
            canvas.leadingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            canvas.trailingAnchor.constraint(equalTo: timeline.leadingAnchor),
            canvas.topAnchor.constraint(equalTo: area.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: area.bottomAnchor)
        ])
        refresh()
    }

    private func control(_ title: String, icon: String?, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .white
        if let icon {
            configuration.image = Bundle.main.resourceURL
                .map { $0.appendingPathComponent("Content/Icons/\(icon).png").path }
                .flatMap { UIImage(contentsOfFile: $0)?.resizedIcon() }
        }
        if !title.hasSuffix("кадр") || configuration.image == nil { configuration.title = title }
        configuration.imagePlacement = .top
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { value in
            var result = value
            result.font = UIFont(name: "Roboto-Regular", size: 12) ?? .systemFont(ofSize: 12)
            return result
        }
        button.configuration = configuration
        button.accessibilityLabel = title
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func seek(_ index: Int) {
        workspace.index = min(workspace.document.frames.count - 1, max(0, index))
        workspace.notify()
        refresh()
    }

    private func refresh() {
        navigator.count = workspace.document.frames.count
        navigator.current = workspace.index
        canvas.setNeedsDisplay()
    }

    private func tween() {
        guard let start = tweenStart else {
            tweenStart = workspace.index
            let alert = UIAlertController(title: "Переход камеры", message: "Выберите конечный кадр, настройте камеру и снова нажмите «Переход».", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { [weak self] _ in self?.tweenStart = nil })
            present(alert, animated: true)
            return
        }
        tweenStart = nil
        let first = min(start, workspace.index), last = max(start, workspace.index)
        guard last > first + 1, workspace.document.frames.indices.contains(last) else { return }
        let from = SceneCamera(frame: workspace.document.frames[first])
        let to = SceneCamera(frame: workspace.document.frames[last])
        workspace.checkpoint()
        for index in (first + 1)..<last {
            let progress = Double(index - first) / Double(last - first)
            from.interpolated(to: to, progress: progress).write(to: &workspace.document.frames[index])
        }
        workspace.notify()
        refresh()
    }
}
