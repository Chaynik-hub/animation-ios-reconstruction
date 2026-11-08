import UIKit

final class UnitListPanel: UIView {
    init(caption: String, items: [(String, UIImage?, () -> Void)], canPaste: Bool, paste: @escaping () -> Void) {
        super.init(frame: .zero); accessibilityIdentifier = "UnitListPanel"; backgroundColor = .original(0x212121)
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; addSubview(scroll)
        let stack = UIStackView(); stack.axis = .vertical; stack.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(stack)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo: leadingAnchor), scroll.trailingAnchor.constraint(equalTo: trailingAnchor), scroll.topAnchor.constraint(equalTo: topAnchor), scroll.bottomAnchor.constraint(equalTo: bottomAnchor), stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor), stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
        let label = UILabel(); label.text = caption; label.textColor = .white; label.backgroundColor = .original(0x00bd78); label.textAlignment = .center; label.font = UIFont(name: "Roboto-Regular", size: 12); stack.addArrangedSubview(label); label.heightAnchor.constraint(equalToConstant: 27).isActive = true
        let button = UIButton(type: .system); button.setTitle("ВСТАВИТЬ", for: .normal); button.tintColor = .white; button.isEnabled = canPaste; button.alpha = canPaste ? 1 : 0.2; button.accessibilityIdentifier = "unit_paste"; button.addAction(UIAction { _ in paste() }, for: .touchUpInside); stack.addArrangedSubview(button); button.heightAnchor.constraint(equalToConstant: 62).isActive = true
        for (index, entry) in items.enumerated() {
            let row = UIButton(type: .custom); row.setImage(entry.1, for: .normal); row.imageView?.contentMode = .scaleAspectFit; row.imageView?.backgroundColor = .white
            row.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 56); row.accessibilityLabel = entry.0; row.accessibilityIdentifier = "unit-list-\(index)"; row.addAction(UIAction { _ in entry.2() }, for: .touchUpInside)
            stack.addArrangedSubview(row); row.heightAnchor.constraint(equalToConstant: 80).isActive = true
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class OpacityPanel: UIView {
    let slider = UISlider(), apply = UIButton(type: .system)
    init(value: Float, begin: @escaping () -> Void, change: @escaping (Float) -> Void, end: @escaping () -> Void, close: @escaping () -> Void) {
        super.init(frame: .zero); backgroundColor = .original(0x212121); accessibilityIdentifier = "UnitOpacityPanel"
        slider.minimumValue = 0; slider.maximumValue = 1; slider.value = value; slider.accessibilityLabel = "Прозрачность спрайта"
        slider.addAction(UIAction { _ in begin() }, for: .touchDown)
        slider.addAction(UIAction { [weak self] _ in guard let self else { return }; self.apply.setTitle("\(Int(self.slider.value * 100))%", for: .normal); change(self.slider.value) }, for: .valueChanged)
        slider.addAction(UIAction { _ in end() }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
        apply.setTitle("\(Int(value * 100))%  ✓", for: .normal); apply.tintColor = .white; apply.accessibilityLabel = "Применить прозрачность"; apply.addAction(UIAction { _ in close() }, for: .touchUpInside)
        addSubview(slider); addSubview(apply)
    }
    override func layoutSubviews() { super.layoutSubviews(); apply.frame = CGRect(x: 4, y: 0, width: bounds.width - 4, height: 60); slider.transform = .identity; slider.bounds = CGRect(x: 0, y: 0, width: max(80, bounds.height - 100), height: 40); slider.center = CGPoint(x: bounds.midX, y: bounds.midY + 25); slider.transform = CGAffineTransform(rotationAngle: -.pi / 2) }
    required init?(coder: NSCoder) { fatalError() }
}
