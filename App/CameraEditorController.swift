import UIKit
import AVFoundation

final class CameraEditorController: UIViewController {
    private let workspace: Workspace
    private let audio: AVAudioPlayer?
    private let canvas: SceneCanvas
    private let navigator = FrameNavigator()
    private var tweenStart: Int?
    private let spanLabel = UILabel()
    private let span = UIStackView()

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
        view.backgroundColor = .original(0x3d3e4c)
        canvas.cameraEditing = true
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)

        let back = control("‹", icon: nil) { [weak self] in self?.dismiss(animated: false) }
        let play = control("ПУСК", icon: "main_btn_play", tint: .original(0xff9000)) { [weak self] in
            guard let self else { return }
            self.present(PreviewController(workspace: self.workspace, audio: self.audio), animated: false)
        }
        let transition = control("TWEEN", icon: "btn_tween", tint: .original(0x00c0d8)) { [weak self] in self?.tween() }
        let reset = control("СБРОС", icon: "btn_reset", tint: .original(0xf35454)) { [weak self] in self?.canvas.resetSceneCamera() }
        let undo = control("ОТМЕНА", icon: "main_btn_undo_normal", tint: .original(0x009ac4)) { [weak self] in
            self?.workspace.undo()
            self?.refresh()
        }
        let toolbar = UIStackView(arrangedSubviews: [play, transition, reset])
        back.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(back)
        undo.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(undo)
        toolbar.axis = .vertical
        toolbar.backgroundColor = .original(0x242530)
        undo.backgroundColor = .original(0x242530)
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
        timeline.backgroundColor = .original(0x242530)
        timeline.translatesAutoresizingMaskIntoConstraints = false
        navigator.seek = { [weak self] in self?.seek($0) }
        view.addSubview(timeline)

        spanLabel.font = UIFont(name: "Roboto-Bold", size: 11) ?? .boldSystemFont(ofSize: 11)
        spanLabel.textColor = .white
        spanLabel.textAlignment = .center
        let cancelSpan = UIButton(type: .system)
        cancelSpan.setTitle("×", for: .normal)
        cancelSpan.tintColor = .white
        cancelSpan.backgroundColor = .original(0x943939)
        cancelSpan.accessibilityLabel = "Отменить диапазон Tween"
        cancelSpan.addAction(UIAction { [weak self] _ in
            self?.tweenStart = nil
            self?.refresh()
        }, for: .touchUpInside)
        span.addArrangedSubview(spanLabel)
        span.addArrangedSubview(cancelSpan)
        span.backgroundColor = .original(0x242530)
        span.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(span)

        let area = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: area.leadingAnchor),
            back.leadingAnchor.constraint(equalTo: area.leadingAnchor),
            back.topAnchor.constraint(equalTo: area.topAnchor),
            back.widthAnchor.constraint(equalToConstant: 80),
            back.heightAnchor.constraint(equalToConstant: 28),
            toolbar.topAnchor.constraint(equalTo: back.bottomAnchor),
            span.centerXAnchor.constraint(equalTo: area.centerXAnchor),
            span.topAnchor.constraint(equalTo: area.topAnchor, constant: 8),
            span.heightAnchor.constraint(equalToConstant: 32),
            spanLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 86),
            cancelSpan.widthAnchor.constraint(equalToConstant: 32),
            toolbar.widthAnchor.constraint(equalToConstant: 80),
            toolbar.heightAnchor.constraint(equalTo: area.heightAnchor, multiplier: 0.68),
            undo.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            undo.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            undo.bottomAnchor.constraint(equalTo: area.bottomAnchor),
            undo.heightAnchor.constraint(equalToConstant: 58),
            timeline.trailingAnchor.constraint(equalTo: area.trailingAnchor),
            timeline.topAnchor.constraint(equalTo: area.topAnchor),
            timeline.bottomAnchor.constraint(equalTo: area.bottomAnchor),
            timeline.widthAnchor.constraint(equalToConstant: 60),
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: area.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: area.bottomAnchor)
        ])
        view.sendSubviewToBack(canvas)
        refresh()
    }

    private func control(_ title: String, icon: String?, tint: UIColor = .white, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = tint
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
        span.isHidden = tweenStart == nil
        if let start = tweenStart { spanLabel.text = "Tween  \(start + 1)–\(workspace.index + 1)" }
        navigator.count = workspace.document.frames.count
        navigator.current = workspace.index
        canvas.setNeedsDisplay()
    }

    private func tween() {
        guard let start = tweenStart else {
            tweenStart = workspace.index
            refresh()
            return
        }
        tweenStart = nil
        refresh()
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
