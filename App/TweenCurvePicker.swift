import UIKit

final class TweenCurvePicker: UIViewController {
    private let commit: (TweenCurve, Double, Double) -> Void
    private var selected = TweenCurve.linear
    private var cells: [(TweenCurve, UIButton)] = []
    private let strength = UISlider(), frequency = UISlider()
    private let frequencyTrack = UIView()

    init(commit: @escaping (TweenCurve, Double, Double) -> Void) {
        self.commit = commit
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.60)
        let backdrop = UIButton()
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.addAction(UIAction { [weak self] _ in self?.dismiss(animated: false) }, for: .touchUpInside)
        view.addSubview(backdrop)
        let scroll = UIScrollView()
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 4
        grid.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(grid)
        let all = TweenCurve.allCases
        for first in stride(from: 0, to: all.count, by: 4) {
            let row = UIStackView()
            row.spacing = 4
            row.distribution = .fillEqually
            for index in first..<(first + 4) {
                guard all.indices.contains(index) else { row.addArrangedSubview(UIView()); continue }
                let curve = all[index]
                let cell = UIButton(type: .system)
                cell.addAction(UIAction { [weak self] _ in
                    guard let self else { return }
                    if curve.isCartwheel != self.selected.isCartwheel { self.frequency.value = curve.isCartwheel ? 1 : 6 }
                    self.selected = curve
                    self.refresh()
                }, for: .touchUpInside)
                cells.append((curve, cell))
                row.addArrangedSubview(cell)
            }
            grid.addArrangedSubview(row)
            row.heightAnchor.constraint(equalToConstant: 106).isActive = true
        }
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            grid.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            grid.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            grid.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        let apply = UIButton(type: .system)
        apply.backgroundColor = .original(0x72bd00)
        apply.setTitleColor(.white, for: .normal)
        apply.titleLabel?.font = UIFont(name: "Roboto-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        apply.setTitle("ПРИМЕНИТЬ", for: .normal)
        apply.heightAnchor.constraint(equalToConstant: 52).isActive = true
        apply.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let curve = self.selected, strength = Double(self.strength.value) / 11, frequency = Double(self.frequency.value)
            self.dismiss(animated: false) { self.commit(curve, strength, frequency) }
        }, for: .touchUpInside)
        let sliders = UIStackView(arrangedSubviews: [UIView(), frequencyTrack])
        sliders.distribution = .fillEqually
        sliders.spacing = 4
        setup(strength, in: sliders.arrangedSubviews[0], value: 5.5, label: "Интенсивность")
        setup(frequency, in: frequencyTrack, value: 6, label: "Частота")
        frequency.minimumValue = 1
        let sidebar = UIStackView(arrangedSubviews: [apply, sliders])
        sidebar.axis = .vertical
        sidebar.spacing = 12
        sidebar.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let panel = UIStackView(arrangedSubviews: [scroll, sidebar])
        panel.spacing = 8
        panel.backgroundColor = .original(0x303030)
        panel.isLayoutMarginsRelativeArrangement = true
        panel.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        let area = view.safeAreaLayoutGuide
        let height = panel.heightAnchor.constraint(equalToConstant: 320)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            height, panel.heightAnchor.constraint(lessThanOrEqualTo: area.heightAnchor, constant: -12),
            panel.centerXAnchor.constraint(equalTo: area.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: area.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 508)
        ])
        refresh()
    }

    private func setup(_ slider: UISlider, in track: UIView, value: Float, label: String) {
        slider.minimumValue = 0
        slider.maximumValue = 11
        slider.value = value
        slider.tintColor = .original(0x72bd00)
        slider.accessibilityLabel = label
        slider.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        slider.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(slider)
        NSLayoutConstraint.activate([
            slider.centerXAnchor.constraint(equalTo: track.centerXAnchor),
            slider.centerYAnchor.constraint(equalTo: track.centerYAnchor),
            slider.widthAnchor.constraint(equalTo: track.heightAnchor, constant: -12),
            slider.heightAnchor.constraint(equalToConstant: 44)
        ])
        slider.addAction(UIAction { [weak self, weak slider] _ in
            if let slider { slider.value = slider.value.rounded() }
            self?.refresh()
        }, for: .valueChanged)
    }

    private func refresh() {
        frequencyTrack.alpha = selected.isShake || selected.isCartwheel ? 1 : 0
        frequency.maximumValue = selected.isCartwheel ? 12 : 11
        frequency.accessibilityLabel = selected.isCartwheel ? "Количество оборотов" : "Частота"
        strength.isEnabled = selected != .linear
        for (curve, cell) in cells {
            var config = UIButton.Configuration.plain()
            config.title = curve.rawValue
            config.imagePlacement = .top
            config.imagePadding = 4
            config.titleAlignment = .center
            config.baseForegroundColor = .white
            config.contentInsets = .zero
            config.titleTextAttributesTransformer = .init { attributes in
                var result = attributes
                result.font = UIFont(name: "Roboto-Regular", size: 14) ?? .systemFont(ofSize: 14)
                return result
            }
            config.image = graph(curve)
            config.background.backgroundColor = curve == selected ? .original(0x465234) : .clear
            cell.configuration = config
            cell.accessibilityTraits = curve == selected ? [.button, .selected] : .button
        }
    }

    private func graph(_ curve: TweenCurve) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { image in
            let ctx = image.cgContext
            ctx.setStrokeColor(UIColor(white: 1, alpha: 0.3).cgColor)
            ctx.stroke(CGRect(x: 6, y: 8, width: 68, height: 64))
            ctx.setStrokeColor(UIColor.original(0x9ce83f).cgColor)
            ctx.setLineWidth(2)
            for index in 0...64 {
                let t = Double(index) / 64
                let power = Double(strength.value) / 11
                var y = curve.progress(t, strength: power)
                if curve.isShake { y = 0.5 + sin(t * Double(frequency.value) * 2 * .pi) * power * 0.35 }
                if curve == .cartwheelCW || curve == .cartwheelCCW {
                    y = 0.5 + sin((t + (t*t*(3-2*t)-t)*power) * Double(frequency.value) * 2 * .pi) * (curve == .cartwheelCW ? -0.35 : 0.35)
                }
                let point = CGPoint(x: 6 + 68 * t, y: 72 - 64 * y)
                if index == 0 { ctx.move(to: point) } else { ctx.addLine(to: point) }
            }
            ctx.strokePath()
        }.withRenderingMode(.alwaysOriginal)
    }
}
