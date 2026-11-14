import UIKit
import AVFoundation
import UniformTypeIdentifiers

final class CameraEditorController: UIViewController, UIColorPickerViewControllerDelegate, UIDocumentPickerDelegate {
    private let workspace: Workspace
    private let audio: AVAudioPlayer?
    private let editsBackground: Bool
    private let canvas: SceneCanvas
    private let navigator = FrameNavigator()
    private var frameRange: ClosedRange<Int>?
    private var moveBeforeGesture = SceneCamera()
    private let play = UIButton(type: .custom)
    private let tweenButton = UIButton(type: .custom)
    private let undo = UIButton(type: .custom)
    private let thumbnails = UIStackView()
    private var thumbnailHeight: NSLayoutConstraint?
    private var recentBackgrounds: [[String: String]] = []
    private var displayedBackgrounds: [[String: String]] = []
    private let span = UIStackView()
    private let spanLabel = UIButton(type: .system)
    private let entryDocument: SceneDocument

    private struct TweenSpan: Codable {
        var first: Int
        var last: Int
        var firstID: Int
        var lastID: Int
        var curve: TweenCurve
        var strength: Double
        var frequency: Double
    }

    private var spanKey: String { editsBackground ? "nativeBackgroundTweens" : "nativeCameraTweens" }
    private var spans: [TweenSpan] {
        get {
            guard let data = workspace.document.attributes[spanKey]?.data(using: .utf8) else { return [] }
            let saved = (try? JSONDecoder().decode([TweenSpan].self, from: data)) ?? []
            let indices = Dictionary(workspace.document.frames.enumerated().map { ($0.element.id, $0.offset) },
                                     uniquingKeysWith: { first, _ in first })
            return saved.compactMap { span in
                guard let first = indices[span.firstID], let last = indices[span.lastID], last > first + 1 else { return nil }
                var resolved = span
                resolved.first = first
                resolved.last = last
                return resolved
            }
        }
        set {
            workspace.document.attributes[spanKey] = newValue.isEmpty ? nil :
                (try? JSONEncoder().encode(newValue)).map { String(decoding: $0, as: UTF8.self) }
        }
    }
    private var activeSpan: TweenSpan? {
        spans.first { $0.first <= workspace.index && workspace.index <= $0.last }
    }

    init(workspace: Workspace, audio: AVAudioPlayer?, editsBackground: Bool = false) {
        self.workspace = workspace
        self.audio = audio
        self.editsBackground = editsBackground
        entryDocument = workspace.document
        canvas = SceneCanvas(workspace)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { AnimationSettings.bool("fullScreen", fallback: true) }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .original(0x3d3e4c)
        canvas.cameraEditing = !editsBackground
        canvas.backgroundEditing = editsBackground
        canvas.transformAllowed = { [weak self] in
            guard let self else { return false }
            if self.editsBackground && self.workspace.frame.attributes["nativeBackgroundID"] == nil &&
                self.workspace.frame.attributes["nativeBackgroundImage"] == nil { return false }
            let selection = self.frameRange ?? (self.workspace.index...self.workspace.index)
            guard self.spans.contains(where: { $0.first + 1 <= selection.upperBound && $0.last - 1 >= selection.lowerBound }) else {
                self.moveBeforeGesture = self.move(at: self.workspace.index)
                return true
            }
            self.spanLabel.setTitle("Заблокировано", for: .normal)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refresh() }
            return false
        }
        canvas.transformFinished = { [weak self] in
            guard let self else { return }
            let selection = self.frameRange ?? (self.workspace.index...self.workspace.index)
            if self.frameRange != nil {
                let move = self.move(at: self.workspace.index)
                let before = self.moveBeforeGesture
                for index in selection where index != self.workspace.index {
                    var item = self.move(at: index)
                    item.x += move.x - before.x
                    item.y += move.y - before.y
                    item.zoom = min(self.editsBackground ? 6.6 : 2.2, max(0.2, item.zoom * move.zoom / before.zoom))
                    item.rotation += move.rotation - before.rotation
                    self.write(item, at: index)
                }
            }
            for span in self.spans where selection.contains(span.first) || selection.contains(span.last) {
                self.interpolate(span)
            }
            self.workspace.notify()
            self.refresh()
        }
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)

        let close = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(closeEditor))
        close.edges = .left
        view.addGestureRecognizer(close)
        for gesture in canvas.gestureRecognizers ?? [] { gesture.require(toFail: close) }
        view.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Назад") { [weak self] _ in
            self?.dismiss(animated: false)
            return true
        }]

        configure(play, "ПУСК", "main_btn_play", color: 0xff9000) { [weak self] in
            guard let self else { return }
            self.present(PreviewController(workspace: self.workspace, audio: self.audio), animated: false)
        }
        configure(tweenButton, "TWEEN", "btn_tween", color: 0x00c0d8) { [weak self] in self?.tween() }
        configure(undo, "ОТМЕНА", "main_btn_undo_normal", color: 0x009ac4) { [weak self] in
            self?.workspace.undo()
            self?.refresh()
        }
        let reset = UIButton(type: .custom)
        configure(reset, "СБРОС", "btn_reset", color: 0xf35454) { [weak self] in self?.reset() }

        let toolbar = UIStackView(arrangedSubviews: [play, tweenButton, reset])
        toolbar.axis = .vertical
        toolbar.spacing = editsBackground ? 5 : 0
        if editsBackground {
            let add = UIButton(type: .custom)
            configure(add, "НОВЫЙ ФОН", "bg_btn_add", color: 0xffbc00) { [weak self] in self?.chooseBackground() }
            add.accessibilityIdentifier = "BackgroundAdd"
            toolbar.insertArrangedSubview(add, at: 1)
            configureBackgroundThumbnails()
        }
        let rail = UIView()
        rail.backgroundColor = .original(0x242530)
        rail.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rail)
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        rail.addSubview(scroll)
        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)), for: .normal)
        back.tintColor = .white
        back.accessibilityLabel = "Назад"
        back.accessibilityIdentifier = "StageEditorBack"
        back.translatesAutoresizingMaskIntoConstraints = false
        back.addAction(UIAction { [weak self] _ in self?.dismiss(animated: false) }, for: .touchUpInside)
        rail.addSubview(back)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(toolbar)
        undo.translatesAutoresizingMaskIntoConstraints = false
        rail.addSubview(undo)

        let previous = frameArrow("main_prev_frame", title: "Предыдущий кадр", step: -1)
        let next = frameArrow("main_next_frame", title: "Следующий кадр", step: 1)
        let timeline = UIStackView(arrangedSubviews: [previous, navigator, next])
        timeline.axis = .vertical
        timeline.translatesAutoresizingMaskIntoConstraints = false
        navigator.seek = { [weak self] in self?.seek($0) }
        navigator.selectRange = { [weak self] in self?.toggleFrameRange() }
        view.addSubview(timeline)

        spanLabel.titleLabel?.font = UIFont(name: "Roboto-Bold", size: 11) ?? .boldSystemFont(ofSize: 11)
        spanLabel.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        spanLabel.tintColor = .white
        spanLabel.addAction(UIAction { [weak self] _ in
            guard let self, let active = self.activeSpan else { return }
            self.chooseCurve(first: active.first, last: active.last)
        }, for: .touchUpInside)
        let remove = UIButton(type: .system)
        remove.setImage(UIImage(systemName: "xmark"), for: .normal)
        remove.tintColor = .white
        remove.backgroundColor = .original(0x1a1a1a)
        remove.accessibilityLabel = "Удалить плавный переход"
        remove.addAction(UIAction { [weak self] _ in self?.removeSpan() }, for: .touchUpInside)
        remove.widthAnchor.constraint(equalToConstant: 32).isActive = true
        span.addArrangedSubview(spanLabel)
        span.addArrangedSubview(remove)
        span.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(span)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rail.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            rail.topAnchor.constraint(equalTo: safe.topAnchor),
            rail.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            rail.widthAnchor.constraint(equalToConstant: 80),
            scroll.leadingAnchor.constraint(equalTo: rail.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: rail.trailingAnchor),
            back.leadingAnchor.constraint(equalTo: rail.leadingAnchor),
            back.topAnchor.constraint(equalTo: rail.topAnchor),
            back.widthAnchor.constraint(equalToConstant: 44),
            back.heightAnchor.constraint(equalToConstant: 44),
            scroll.topAnchor.constraint(equalTo: back.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: undo.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: editsBackground ? 5 : 0),
            toolbar.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            toolbar.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            undo.leadingAnchor.constraint(equalTo: rail.leadingAnchor),
            undo.trailingAnchor.constraint(equalTo: rail.trailingAnchor),
            undo.bottomAnchor.constraint(equalTo: rail.bottomAnchor),
            timeline.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            timeline.topAnchor.constraint(equalTo: safe.topAnchor),
            timeline.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            timeline.widthAnchor.constraint(equalToConstant: 60),
            span.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            span.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            span.heightAnchor.constraint(equalToConstant: 32)
        ])
        refresh()
    }

    override func accessibilityPerformEscape() -> Bool {
        dismiss(animated: false)
        return true
    }

    @objc private func closeEditor(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .recognized { dismiss(animated: false) }
    }

    private func icon(_ name: String, density: CGFloat = 3) -> UIImage? {
        Bundle.main.resourceURL
            .map { $0.appendingPathComponent("Content/Icons/\(name).png").path }
            .flatMap { UIImage(contentsOfFile: $0)?.resizedIcon(density: density) }
    }

    private func configure(_ button: UIButton, _ title: String, _ artwork: String, color: UInt32, action: @escaping () -> Void) {
        button.accessibilityLabel = title
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = icon(artwork)
        configuration.imagePlacement = .top
        configuration.imagePadding = 0
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { value in
            var result = value
            result.font = UIFont(name: "Roboto-Regular", size: 12) ?? .systemFont(ofSize: 12)
            return result
        }
        button.configuration = configuration
        button.configurationUpdateHandler = { [weak self] button in
            var state = button.configuration
            state?.baseForegroundColor = .original(color).withAlphaComponent(button.isEnabled ? 1 : 0.22)
            state?.background.backgroundColor = button.isHighlighted ? .original(0x444444) : .clear
            if artwork == "main_btn_undo_normal" {
                state?.image = self?.icon(button.isEnabled ? artwork : "main_btn_undo_disabled")
            } else {
                state?.image = self?.icon(artwork)?.withAlpha(button.isEnabled ? 1 : 0.35)
            }
            button.configuration = state
        }
        button.heightAnchor.constraint(equalToConstant: artwork == "main_btn_undo_normal" ? 61 : 68).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    private func frameArrow(_ name: String, title: String, step: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.setImage(icon(name + "_np", density: 4), for: .normal)
        button.setImage(icon(name + "_pr", density: 4), for: .highlighted)
        button.accessibilityLabel = title
        button.tag = step
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(pageFrames(_:)))
        hold.minimumPressDuration = 0.5
        button.addGestureRecognizer(hold)
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.seek(self.workspace.index + step)
        }, for: .touchUpInside)
        return button
    }

    @objc private func pageFrames(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began, let step = gesture.view?.tag { seek(navigator.pageTarget(step)) }
    }

    private func seek(_ index: Int) {
        let limits = frameRange ?? (0...(workspace.document.frames.count - 1))
        workspace.index = min(limits.upperBound, max(limits.lowerBound, index))
        workspace.notify(save: false)
        refresh()
    }

    private func refresh() {
        let count = workspace.document.frames.count
        play.isEnabled = count > 1
        tweenButton.isEnabled = count > 2
        undo.isEnabled = !workspace.history.isEmpty && workspace.document != entryDocument
        navigator.count = count
        navigator.current = workspace.index
        navigator.selectedRange = frameRange
        span.isHidden = activeSpan == nil || frameRange != nil
        let colors: [UInt32] = [0xff1744, 0xff6d00, 0xffab00, 0x00c853, 0x00bfa5, 0x00b8d4,
                                0x2979ff, 0x651fff, 0xd500f9, 0xf50057, 0xff3d00]
        if let curve = activeSpan?.curve, let index = TweenCurve.allCases.firstIndex(of: curve) {
            spanLabel.backgroundColor = .original(colors[index])
        }
        if editsBackground { refreshBackgroundThumbnails() }
        spanLabel.setTitle(activeSpan.map { $0.curve.rawValue }, for: .normal)
        canvas.cameraFrameLocked = activeSpan.map { $0.first < workspace.index && workspace.index < $0.last } ?? false
        canvas.setNeedsDisplay()
    }

    private func toggleFrameRange() {
        guard workspace.document.frames.count > 3 else { return }
        if frameRange != nil {
            frameRange = nil
            refresh()
            return
        }
        selectRange(title: "Выбрать кадры", first: workspace.index, last: workspace.document.frames.count - 1,
                    minimumLength: 1) { [weak self] first, last in
            self?.frameRange = first...last
            self?.seek(first)
        }
    }

    private func reset() {
        if let frameRange {
            workspace.checkpoint()
            let previous = spans
            spans = previous.filter { $0.last < frameRange.lowerBound || $0.first > frameRange.upperBound }
            if spans.count == previous.count {
                for index in frameRange { write(SceneCamera(), at: index) }
            }
            workspace.notify()
            refresh()
            return
        }
        if activeSpan != nil {
            removeSpan()
            return
        }
        guard move(at: workspace.index) != SceneCamera() else { return }
        workspace.checkpoint()
        write(SceneCamera(), at: workspace.index)
        workspace.notify()
        refresh()
    }

    private func removeSpan() {
        guard let active = activeSpan else { return }
        workspace.checkpoint()
        spans = spans.filter { $0.first != active.first || $0.last != active.last }
        workspace.notify()
        refresh()
    }

    private func move(at index: Int) -> SceneCamera {
        SceneCamera(frame: workspace.document.frames[index], background: editsBackground)
    }

    private func write(_ move: SceneCamera, at index: Int) {
        move.write(to: &workspace.document.frames[index], background: editsBackground)
    }

    private func interpolate(_ span: TweenSpan) {
        guard workspace.document.frames.indices.contains(span.first),
              workspace.document.frames.indices.contains(span.last), span.last > span.first + 1 else { return }
        let start = move(at: span.first)
        let end = move(at: span.last)
        for index in (span.first + 1)..<span.last {
            let progress = Double(index - span.first) / Double(span.last - span.first)
            let value = span.curve.progress(progress, strength: span.strength)
            var pose = start.interpolated(to: end, progress: value)
            if span.curve.isShake {
                let horizontal = span.curve == .shakeX
                let travel = horizontal ? abs(end.x - start.x) : abs(end.y - start.y)
                let offset = span.curve.shakeOffset(at: progress, travel: travel, strength: span.strength, frequency: span.frequency)
                if horizontal { pose.x += offset }
                else { pose.y += offset }
            }
            if span.curve.isCartwheel {
                pose.rotation += span.curve.cartwheelAngle(at: progress, strength: span.strength, turns: span.frequency)
            }
            write(pose, at: index)
        }
    }

    private func tween() {
        let last = workspace.document.frames.count - 1
        guard last >= 2 else { return }
        let first = frameRange?.lowerBound ?? (last - workspace.index < 3 ? 0 : workspace.index)
        selectRange(title: editsBackground ? "Плавный переход фона" : "Движение камеры от кадра к кадру",
                    first: first, last: frameRange?.upperBound ?? last, minimumLength: 3) { [weak self] first, last in
            self?.chooseCurve(first: first, last: last)
        }
    }

    private func chooseCurve(first: Int, last: Int) {
        let overlap = spans.contains { first < $0.last && last > $0.first && (first != $0.first || last != $0.last) }
        guard !overlap else {
            showMessage("Диапазоны переходов пересекаются")
            return
        }
        if editsBackground {
            let keys = Self.backgroundKeys
            guard (first...last).allSatisfy({ index in
                keys.allSatisfy { workspace.document.frames[first].attributes[$0] == workspace.document.frames[index].attributes[$0] }
            }) else {
                showMessage("На кадрах диапазона должен быть один фон")
                return
            }
        }
        let existing = spans.first { $0.first == first && $0.last == last }
        let picker = TweenCurvePicker(initial: existing.map { ($0.curve, $0.strength, $0.frequency) }) { [weak self] curve, strength, frequency in
            guard let self else { return }
            self.workspace.checkpoint()
            let span = TweenSpan(first: first, last: last,
                                firstID: self.workspace.document.frames[first].id,
                                lastID: self.workspace.document.frames[last].id, curve: curve, strength: strength, frequency: frequency)
            self.spans = self.spans.filter { $0.first != first || $0.last != last } + [span]
            self.interpolate(span)
            self.workspace.notify()
            self.refresh()
        }
        picker.modalPresentationStyle = .overFullScreen
        present(picker, animated: false)
    }

    private func selectRange(title: String, first: Int, last: Int, minimumLength: Int, apply: @escaping (Int, Int) -> Void) {
        let controller = StageRangeController(workspace: workspace, title: title, first: first, last: last,
                                              minimumLength: minimumLength, apply: apply)
        controller.modalPresentationStyle = .overFullScreen
        present(controller, animated: false)
    }

    private func showMessage(_ title: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: false)
    }

    private func chooseBackground() {
        let picker = BackgroundChooserController(values: workspace.backgroundCatalog, select: { [weak self] item in
            self?.dismiss(animated: false) { [weak self] in
                guard let item else { return }
                self?.applyBackgroundToSelection(["nativeBackgroundID": item.id])
            }
        }, close: { [weak self] in self?.dismiss(animated: false) }, actions: [
            { [weak self] in self?.dismiss(animated: false) { [weak self] in self?.pickColor() } },
            { [weak self] in self?.dismiss(animated: false) { [weak self] in self?.pickImage() } },
            { [weak self] in self?.dismiss(animated: false) { [weak self] in self?.drawBackground() } }
        ], resolve: workspace.artworkURL)
        picker.modalPresentationStyle = .overFullScreen
        present(picker, animated: false)
    }

    private func configureBackgroundThumbnails() {
        let scroll = UIScrollView()
        scroll.backgroundColor = .original(0x444444)
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        thumbnails.axis = .vertical
        thumbnails.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(thumbnails)
        let height = scroll.heightAnchor.constraint(equalToConstant: 0)
        height.priority = .defaultHigh
        thumbnailHeight = height
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 80),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor),
            height,
            scroll.widthAnchor.constraint(equalToConstant: 72),
            thumbnails.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            thumbnails.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            thumbnails.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            thumbnails.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            thumbnails.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
    }

    private static let backgroundKeys = ["nativeBackgroundID", "nativeBackgroundColor", "nativeBackgroundImage"]

    private func refreshBackgroundThumbnails() {
        let colors: [UInt32] = [0x18574a, 0xf5be67, 0xda9ee6, 0x5899a6, 0xf79779, 0x486641]
        let used = workspace.document.frames.map { frame in
            frame.attributes.filter { Self.backgroundKeys.contains($0.key) }
        }
        var seen = Set<[String]>()
        var options = (used + recentBackgrounds).filter { values in
            seen.insert(Self.backgroundKeys.map { values[$0] ?? "" }).inserted
        }
        if options.count == 1 && options[0]["nativeBackgroundID"] == nil && options[0]["nativeBackgroundImage"] == nil {
            for color in colors {
                let item = ["nativeBackgroundColor": Self.colorString(.original(color))]
                if !options.contains(item) { options.append(item) }
            }
        }
        guard displayedBackgrounds != options else { return }
        displayedBackgrounds = options
        thumbnails.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in options {
            let row = UIButton(type: .custom)
            let frame = SceneFrame(id: 0, units: [], attributes: item)
            let image = UIImageView(frame: CGRect(x: 6, y: 6, width: 60, height: 60))
            image.contentMode = .scaleAspectFit
            image.backgroundColor = canvas.frameBackgroundColor(frame) ?? .original(0xd9d9d9)
            if let id = item["nativeBackgroundID"], let definition = workspace.backgroundCatalog.first(where: { $0.id == id }) {
                image.image = workspace.artworkURL(definition.thumbnail).flatMap { UIImage(contentsOfFile: $0.path) }
                row.accessibilityLabel = definition.title
            } else if let path = item["nativeBackgroundImage"], let url = workspace.artworkURL(path) {
                image.image = UIImage(contentsOfFile: url.path)
            }
            row.accessibilityLabel = row.accessibilityLabel ?? "Фон"
            row.addSubview(image)
            row.heightAnchor.constraint(equalToConstant: 72).isActive = true
            row.addAction(UIAction { [weak self] _ in self?.applyBackgroundToSelection(item) }, for: .touchUpInside)
            row.menu = UIMenu(children: [
                UIAction(title: "Установить фон для ряда кадров") { [weak self] _ in self?.applyBackgroundToRange(item) }
            ])
            thumbnails.addArrangedSubview(row)
        }
        thumbnailHeight?.constant = CGFloat(options.count) * 72
    }

    private static func colorString(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return "\(r),\(g),\(b),\(a)"
    }

    private func pickColor() {
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.selectedColor = canvas.frameBackgroundColor(workspace.frame) ?? .white
        present(picker, animated: false)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        let color = Self.colorString(viewController.selectedColor)
        afterPicker(viewController) { [weak self] in self?.applyBackgroundToSelection(["nativeBackgroundColor": color]) }
    }

    private func pickImage() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
        picker.delegate = self
        present(picker, animated: false)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let image = UIImage(contentsOfFile: url.path)
        let title = url.deletingPathExtension().lastPathComponent
        afterPicker(controller) { [weak self] in
            if let image { self?.saveBackground(image, title: title) }
            else { self?.showMessage("Не удалось открыть изображение") }
        }
    }

    private func afterPicker(_ controller: UIViewController, _ completion: @escaping () -> Void) {
        if controller.isBeingDismissed, let transition = controller.transitionCoordinator {
            transition.animate(alongsideTransition: nil) { _ in completion() }
        } else if presentedViewController === controller {
            controller.dismiss(animated: false, completion: completion)
        } else {
            completion()
        }
    }

    private func drawBackground() {
        let size = CGSize(width: workspace.document.width, height: workspace.document.height)
        let controller = BackgroundDrawingController(size: size) { [weak self] image in
            self?.saveBackground(image, title: "Рисунок")
        }
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: false)
    }

    private func saveBackground(_ image: UIImage, title: String) {
        do {
            let item = try UserBackgroundLibrary.save(image, title: title, directory: workspace.directory)
            workspace.backgroundLibraryCache = nil
            applyBackgroundToSelection(["nativeBackgroundID": item.id])
        } catch {
            showMessage("Не удалось сохранить фон")
        }
    }

    private func applyBackgroundToSelection(_ values: [String: String]) {
        let selection = frameRange ?? (workspace.index...workspace.index)
        installBackground(values, first: selection.lowerBound, last: selection.upperBound)
    }

    private func applyBackgroundToRange(_ values: [String: String]) {
        let last = workspace.document.frames.count - 1
        if last == 0 {
            installBackground(values, first: 0, last: 0)
        } else {
            selectRange(title: "Установить фон для ряда кадров", first: frameRange?.lowerBound ?? 0,
                        last: frameRange?.upperBound ?? last, minimumLength: 1) { [weak self] first, last in
                self?.installBackground(values, first: first, last: last)
            }
        }
    }

    private func installBackground(_ values: [String: String], first: Int, last: Int) {
        workspace.checkpoint()
        if !recentBackgrounds.contains(values) { recentBackgrounds.append(values) }
        spans = spans.filter { last < $0.first || first > $0.last }
        for index in first...last {
            for key in Self.backgroundKeys {
                workspace.document.frames[index].attributes[key] = values[key]
            }
            workspace.document.frames[index].attributes["nativeBackgroundFit"] = "width"
            SceneCamera().write(to: &workspace.document.frames[index], background: true)
        }
        workspace.notify()
        refresh()
    }
}

private final class StageRangeController: UIViewController {
    private let workspace: Workspace
    private let start = UISlider()
    private let end = UISlider()
    private let startLabel = UILabel()
    private let endLabel = UILabel()
    private let applyButton = UIButton(type: .system)
    private let firstPreview: SceneCanvas
    private let lastPreview: SceneCanvas
    private let heading: String
    private let minimumLength: Int
    private let apply: (Int, Int) -> Void

    init(workspace: Workspace, title: String, first: Int, last: Int, minimumLength: Int,
         apply: @escaping (Int, Int) -> Void) {
        self.workspace = workspace
        heading = title
        self.minimumLength = minimumLength
        self.apply = apply
        firstPreview = SceneCanvas(workspace)
        lastPreview = SceneCanvas(workspace)
        super.init(nibName: nil, bundle: nil)
        for slider in [start, end] { slider.maximumValue = Float(workspace.document.frames.count - 1) }
        start.value = Float(first)
        end.value = Float(last)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.60)
        let title = UILabel()
        title.text = heading
        title.textColor = .white
        title.numberOfLines = 0
        title.font = UIFont(name: "Roboto-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        for label in [startLabel, endLabel] { label.textColor = .white }
        start.accessibilityLabel = "Первый кадр"
        end.accessibilityLabel = "Последний кадр"
        for slider in [start, end] {
            slider.addTarget(self, action: #selector(updatePreview(_:)), for: .valueChanged)
        }
        applyButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let first = Int(self.start.value), last = Int(self.end.value)
            self.dismiss(animated: false) { self.apply(first, last) }
        }, for: .touchUpInside)
        title.textAlignment = .center
        let previews = UIStackView()
        previews.distribution = .fillEqually
        for (preview, color) in [(firstPreview, UInt32(0x72bd00)), (lastPreview, UInt32(0xf35454))] {
            let frame = UIView()
            frame.backgroundColor = .original(color)
            preview.handles = false
            preview.isUserInteractionEnabled = false
            preview.translatesAutoresizingMaskIntoConstraints = false
            frame.addSubview(preview)
            NSLayoutConstraint.activate([
                preview.topAnchor.constraint(equalTo: frame.topAnchor, constant: 10),
                preview.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 10),
                preview.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -10),
                preview.bottomAnchor.constraint(equalTo: frame.bottomAnchor, constant: -10)
            ])
            previews.addArrangedSubview(frame)
        }
        let previewHeight = previews.heightAnchor.constraint(equalToConstant: 200)
        previewHeight.priority = .defaultHigh
        previewHeight.isActive = true

        let applyIcon = workspace.artworkURL("Icons/main_btn_play.png").flatMap { UIImage(contentsOfFile: $0.path) }?.resizedIcon()
        applyButton.setImage(applyIcon, for: .normal)
        applyButton.accessibilityLabel = "Применить"
        applyButton.translatesAutoresizingMaskIntoConstraints = false

        let frames = UIStackView(arrangedSubviews: [startLabel, start, endLabel, end])
        frames.spacing = 8
        frames.alignment = .center
        startLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        endLabel.font = startLabel.font
        start.tintColor = .original(0x00c5ff)
        end.tintColor = .original(0x00c5ff)
        start.widthAnchor.constraint(equalTo: end.widthAnchor).isActive = true
        let panel = UIStackView(arrangedSubviews: [title, previews, frames])
        panel.axis = .vertical
        panel.spacing = 6
        panel.backgroundColor = .original(0x3e3e3e)
        panel.isLayoutMarginsRelativeArrangement = true
        panel.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        panel.translatesAutoresizingMaskIntoConstraints = false
        let backdrop = UIButton(type: .custom)
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.accessibilityLabel = "Отмена"
        backdrop.addAction(UIAction { [weak self] _ in self?.dismiss(animated: false) }, for: .touchUpInside)
        view.addSubview(backdrop)
        view.addSubview(panel)
        view.addSubview(applyButton)
        let safe = view.safeAreaLayoutGuide
        let width = panel.widthAnchor.constraint(equalToConstant: 416)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            panel.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -24),
            width,
            panel.heightAnchor.constraint(lessThanOrEqualTo: safe.heightAnchor, constant: -20),
            applyButton.centerXAnchor.constraint(equalTo: previews.centerXAnchor),
            applyButton.bottomAnchor.constraint(equalTo: previews.bottomAnchor, constant: -5),
            applyButton.widthAnchor.constraint(equalToConstant: 52),
            applyButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        updatePreview(start)
    }

    @objc private func updatePreview(_ slider: UISlider) {
        slider.value = slider.value.rounded()
        let first = Int(start.value), last = Int(end.value)
        startLabel.text = String(first + 1)
        endLabel.text = String(last + 1)
        applyButton.isEnabled = last - first + 1 >= minimumLength
        firstPreview.displayed = workspace.document.frames[first]
        lastPreview.displayed = workspace.document.frames[last]
        firstPreview.setNeedsDisplay()
        lastPreview.setNeedsDisplay()
    }
}

private extension UIImage {
    func withAlpha(_ alpha: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(at: .zero, blendMode: .normal, alpha: alpha)
        }.withRenderingMode(.alwaysOriginal)
    }
}
