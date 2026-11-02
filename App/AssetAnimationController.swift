import UIKit
final class AssetAnimationController: UIViewController {
    let frameIDs: [Int], commit: (AssetAnimation.Configuration?) -> Void
    let enabled = UISwitch(), reverse = UISwitch(), speed = UISlider(), label = UILabel(), start = UITextField(), end = UITextField()
    let initial: AssetAnimation.Configuration?
    init(configuration: AssetAnimation.Configuration?, frameIDs: [Int], commit: @escaping (AssetAnimation.Configuration?) -> Void) { self.initial = configuration; self.frameIDs = frameIDs; self.commit = commit; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        let scroll=UIScrollView();scroll.backgroundColor = .original(0x303030);scroll.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(scroll)
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 15; stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16); stack.isLayoutMarginsRelativeArrangement = true; stack.backgroundColor = .original(0x303030); stack.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(stack)
        enabled.isOn = initial != nil; enabled.accessibilityIdentifier = "AssetAnimationEnabled"
        reverse.isOn = initial?.pingPong ?? false; reverse.accessibilityIdentifier = "AssetAnimationReverse"
        speed.minimumValue = 0; speed.maximumValue = 10; speed.value = Float(10 - ((initial?.period ?? 28) - 3) / 5); speed.accessibilityLabel = "Скорость анимации"
        speed.addAction(UIAction { [weak self] _ in self?.updateLabel() }, for: .valueChanged)
        for (text, control) in [("Анимация", enabled), ("Прямой и обратный порядок", reverse)] {
            let caption = UILabel(); caption.text = text; caption.textColor = .white; caption.numberOfLines = 2
            let row = UIStackView(arrangedSubviews: [caption, control]); row.spacing = 10; stack.addArrangedSubview(row)
        }
        label.textColor = .white; stack.addArrangedSubview(label); stack.addArrangedSubview(speed)
        for (field, caption, value) in [(start, "Первый кадр сцены", (initial?.startID.flatMap { frameIDs.firstIndex(of: $0) } ?? 0) + 1), (end, "Последний кадр сцены", (initial?.endID.flatMap { frameIDs.firstIndex(of: $0) } ?? max(0, frameIDs.count - 1)) + 1)] {
            field.text = String(value); field.placeholder = caption; field.accessibilityLabel = caption; field.borderStyle = .roundedRect; field.keyboardType = .numberPad
            let text = UILabel(); text.text = caption; text.textColor = .white; let row = UIStackView(arrangedSubviews: [text, field]); row.spacing = 10; field.widthAnchor.constraint(equalToConstant: 65).isActive = true; stack.addArrangedSubview(row)
        }
        let done = UIButton(type: .system); done.setTitle("OK", for: .normal); done.accessibilityIdentifier = "AssetAnimationApply"
        done.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside); stack.addArrangedSubview(done)
        let cancel = UIButton(type: .system); cancel.setTitle("Отмена", for: .normal); cancel.addAction(UIAction { [weak self] _ in self?.dismiss(animated: false) }, for: .touchUpInside); stack.addArrangedSubview(cancel)
        NSLayoutConstraint.activate([scroll.centerXAnchor.constraint(equalTo:view.centerXAnchor),scroll.centerYAnchor.constraint(equalTo:view.centerYAnchor),scroll.widthAnchor.constraint(equalToConstant:340),scroll.heightAnchor.constraint(equalTo:view.safeAreaLayoutGuide.heightAnchor,constant:-20),stack.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor),stack.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor),stack.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor),stack.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor),stack.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor)])
        stack.setCustomSpacing(6, after: label); updateLabel()
    }
    private func updateLabel() { speed.value = speed.value.rounded(); label.text = "Скорость анимации \(Int(speed.value))" }
    private func save() {
        guard let a = Int(start.text ?? ""), let b = Int(end.text ?? ""), a > 0, b >= a, b <= frameIDs.count else { return }
        commit(enabled.isOn ? AssetAnimation.Configuration(period: 53 - Int(speed.value.rounded()) * 5, pingPong: reverse.isOn, startID: frameIDs[a - 1], endID: frameIDs[b - 1]) : nil); dismiss(animated: false)
    }
}
