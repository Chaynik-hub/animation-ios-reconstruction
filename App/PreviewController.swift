import UIKit
import AVFoundation

/// Separate preview, with an explicit iOS equivalent of Android's Back action.
final class PreviewController: UIViewController, UIGestureRecognizerDelegate {
    let workspace: Workspace
    let audio: AVAudioPlayer?
    lazy var canvas = SceneCanvas(workspace)
    private var link: CADisplayLink?
    private var start = 0.0
    private var accumulated = 0.0
    private var playing = true
    private var finished = false
    private let counter = UILabel()
    private let replay = UIButton(type: .system)
    private let timeline = UISlider()
    private var ticksPerFrame: Int { max(1, workspace.document.interframes + 1) }
    private var lastTick: Int { max(0, workspace.document.frames.count - 1) * ticksPerFrame }
    init(workspace: Workspace, audio: AVAudioPlayer?) {
        self.workspace = workspace; self.audio = audio
        super.init(nibName: nil, bundle: nil); modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError() }
    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .original(0x222222)
        canvas.frame = view.bounds; canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.handles = false; canvas.onion = false; canvas.isUserInteractionEnabled = false
        canvas.accessibilityIdentifier = "PreviewCanvas"; canvas.isAccessibilityElement = true; view.addSubview(canvas)
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggle)); tap.delegate = self; view.addGestureRecognizer(tap)
        let back = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(back(_:))); back.edges = .left; view.addGestureRecognizer(back)
        let close = UIButton(type: .system); close.setTitle("‹", for: .normal); close.titleLabel?.font = .systemFont(ofSize: 32); close.tintColor = .white
        close.backgroundColor = UIColor.black.withAlphaComponent(0.6); close.accessibilityLabel = "Закрыть просмотр"; close.accessibilityIdentifier = "PreviewClose"
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: false) }, for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(close)
        counter.textColor = .original(0xffff33); counter.font = UIFont(name: "Roboto-Regular", size: 12); counter.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(counter)
        replay.setTitle("ЕЩЁ РАЗ", for: .normal); replay.tintColor = .white; replay.backgroundColor = UIColor.original(0x111111).withAlphaComponent(136.0 / 255.0)
        replay.titleLabel?.font = UIFont(name: "Roboto-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        replay.accessibilityIdentifier = "PreviewReplay"; replay.addAction(UIAction { [weak self] _ in self?.restart() }, for: .touchUpInside)
        replay.translatesAutoresizingMaskIntoConstraints = false; replay.isHidden = true; view.addSubview(replay)
        timeline.minimumValue = 0
        timeline.maximumValue = Float(lastTick)
        timeline.isEnabled = lastTick > 0
        timeline.tintColor = .original(0xffff33)
        timeline.accessibilityLabel = "Кадр просмотра"
        timeline.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        timeline.translatesAutoresizingMaskIntoConstraints = false
        timeline.addAction(UIAction { [weak self] _ in self?.scrub() }, for: [.touchDown, .valueChanged])
        view.addSubview(timeline)
        view.bringSubviewToFront(close)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            close.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), close.topAnchor.constraint(equalTo: view.topAnchor), close.widthAnchor.constraint(equalToConstant: 44), close.heightAnchor.constraint(equalToConstant: 44),
            counter.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 50), counter.topAnchor.constraint(equalTo: view.topAnchor),
            replay.leadingAnchor.constraint(equalTo: view.leadingAnchor), replay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            replay.topAnchor.constraint(equalTo: view.topAnchor), replay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            timeline.centerXAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),
            timeline.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            timeline.widthAnchor.constraint(equalTo: safe.heightAnchor, constant: -20),
            timeline.heightAnchor.constraint(equalToConstant: 44)
        ])
        render(tick: 0)
        start = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:))); link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common); self.link = link; audio?.currentTime = 0; audio?.play()
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let view = target { if view is UIControl { return false }; target = view.superview }
        return true
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); link?.invalidate(); link = nil; audio?.pause() }
    override func accessibilityPerformEscape() -> Bool { dismiss(animated: false); return true }
    @objc private func back(_ gesture: UIScreenEdgePanGestureRecognizer) { if gesture.state == .ended && gesture.translation(in: view).x > 40 { dismiss(animated: false) } }
    private func restart() { timeline.value = 0; link?.isPaused = false; accumulated = 0; start = CACurrentMediaTime(); finished = false; playing = true; replay.isHidden = true; audio?.currentTime = 0; audio?.play() }
    @objc private func toggle() {
        if finished { restart(); return }
        playing.toggle()
        link?.isPaused = !playing
        if playing { start = CACurrentMediaTime(); audio?.play() } else { accumulated += CACurrentMediaTime() - start; audio?.pause() }
    }
    private func scrub() {
        let tick = Int(timeline.value.rounded())
        timeline.value = Float(tick)
        accumulated = Double(tick) / 60
        playing = false
        finished = false
        replay.isHidden = true
        link?.isPaused = true
        audio?.pause()
        if let audio { audio.currentTime = min(audio.duration, accumulated) }
        render(tick: tick)
    }

    @objc private func tick(_ sender: CADisplayLink) {
        let time = accumulated + max(0, sender.timestamp - start)
        let tick = min(lastTick, Int(time * 60))
        timeline.value = Float(tick)
        render(tick: tick)
        if tick == lastTick {
            accumulated = Double(tick) / 60
            playing = false
            finished = true
            link?.isPaused = true
            audio?.pause()
            replay.isHidden = false
        }
    }

    private func render(tick: Int) {
        guard !workspace.document.frames.isEmpty else { return }
        let index = min(workspace.document.frames.count - 1, tick / ticksPerFrame)
        let current = workspace.document.frames[index]
        let following = workspace.document.frames[min(index + 1, workspace.document.frames.count - 1)]
        let progress = Double(tick % ticksPerFrame) / Double(ticksPerFrame)
        let frame = (try? FrameInterpolation.between(current, following, progress: progress)) ?? current
        canvas.displayed = workspace.applyAssetAnimations(to: frame, tick: tick)
        counter.text = String(tick + 1)
        timeline.accessibilityValue = "\(tick + 1) / \(lastTick + 1)"
        canvas.setNeedsDisplay()
    }
}
