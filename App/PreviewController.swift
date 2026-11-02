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
        replay.setTitle("Нажмите для повтора", for: .normal); replay.tintColor = .white; replay.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        replay.accessibilityIdentifier = "PreviewReplay"; replay.addAction(UIAction { [weak self] _ in self?.restart() }, for: .touchUpInside)
        replay.translatesAutoresizingMaskIntoConstraints = false; replay.isHidden = true; view.addSubview(replay)
        NSLayoutConstraint.activate([
            close.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), close.topAnchor.constraint(equalTo: view.topAnchor), close.widthAnchor.constraint(equalToConstant: 44), close.heightAnchor.constraint(equalToConstant: 44),
            counter.leadingAnchor.constraint(equalTo: close.trailingAnchor, constant: 6), counter.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            replay.centerXAnchor.constraint(equalTo: view.centerXAnchor), replay.centerYAnchor.constraint(equalTo: view.centerYAnchor), replay.widthAnchor.constraint(equalToConstant: 230), replay.heightAnchor.constraint(equalToConstant: 60)
        ])
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
    private func restart() { accumulated = 0; start = CACurrentMediaTime(); finished = false; playing = true; replay.isHidden = true; audio?.currentTime = 0; audio?.play() }
    @objc private func toggle() {
        if finished { restart(); return }
        playing.toggle()
        if playing { start = CACurrentMediaTime(); audio?.play() } else { accumulated += CACurrentMediaTime() - start; audio?.pause() }
    }
    @objc private func tick(_ sender: CADisplayLink) {
        guard !workspace.document.frames.isEmpty else { return }
        let time = accumulated + (playing ? sender.timestamp - start : 0)
        let duration = Double(max(1, workspace.document.interframes + 1)) / 60
        let position = max(0, time / duration)
        let count = workspace.document.frames.count
        let last = Double(max(0, count - 1))
        if position >= last {
            canvas.displayed = workspace.document.frames[count - 1]
            if !finished { accumulated = last * duration; playing = false; finished = true; audio?.pause(); replay.isHidden = false }
            counter.text = String(count)
        } else {
            let index = Int(position), current = workspace.document.frames[index], next = workspace.document.frames[index + 1]
            canvas.displayed = (try? FrameInterpolation.between(current, next, progress: position - floor(position))) ?? current
            counter.text = String(index + 1)
        }
        canvas.setNeedsDisplay()
    }
}
