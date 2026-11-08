import UIKit
import CoreText

enum SpriteText {
    static let plainName = "common:text"
    static let definition = ArtworkDefinition(name: plainName, points: [
        ["id": "1", "base": "true", "x": "0", "y": "0"],
        ["id": "2", "par": "1", "x": "120", "y": "0"]
    ], parts: [], thumbnail: "Icons/props_text.png", defaultScale: 1,
    titles: ["ru": "Текст", "en": "Text"], packID: "common", folderPath: [], catalogOrder: nil)

    static func isBubble(_ unit: SceneUnit) -> Bool {
        unit.attributes["type"] == "bubble" || UnitIdentity.baseName(unit.name) == "common:bubble"
    }

    static func isEditable(_ unit: SceneUnit) -> Bool {
        isBubble(unit) || unit.attributes["type"] == "text" || UnitIdentity.baseName(unit.name) == plainName
    }

    static func value(_ unit: SceneUnit) -> String { unit.attributes["nativeText"] ?? unit.attributes["text"] ?? "" }

    static func color(_ unit: SceneUnit) -> UIColor {
        let rgb = UInt32(unit.attributes["nativeTextColor"] ?? "", radix: 16) ?? 0x111111
        return .original(rgb)
    }

    static func draw(_ unit: SceneUnit, in rect: CGRect, context: CGContext, alpha: CGFloat) {
        let value = value(unit)
        guard !value.isEmpty, rect.width > 0, rect.height > 0 else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byCharWrapping
        var attributes: [NSAttributedString.Key: Any] = [.paragraphStyle: paragraph, .foregroundColor: color(unit)]
        let text = value as NSString
        let fontName = unit.attributes["nativeTextFont"] ?? "Roboto-Regular"
        var height: CGFloat = 0
        for size in stride(from: Int(min(32, rect.height)), through: 5, by: -1) {
            attributes[.font] = UIFont(name: fontName, size: CGFloat(size)) ?? UIFont.systemFont(ofSize: CGFloat(size))
            height = text.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                       options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).height
            if height <= rect.height { break }
        }
        context.saveGState()
        context.clip(to: rect)
        context.setAlpha(alpha)
        text.draw(with: CGRect(x: rect.minX, y: rect.minY + max(0, (rect.height - height) / 2),
                               width: rect.width, height: max(rect.height, height)),
                  options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        context.restoreGState()
    }

    static func drawPlain(_ unit: SceneUnit, in context: CGContext, opacity: CGFloat) {
        guard let first = unit.joints.first(where: { $0.attributes["base"] == "true" }) else { return }
        let end = unit.joints.first(where: { $0.parent == first.id })
        let dx = (end?.x ?? first.x + 120) - first.x
        let dy = (end?.y ?? first.y) - first.y
        let width = max(10, hypot(dx, dy))
        context.saveGState()
        context.translateBy(x: first.x, y: first.y)
        context.rotate(by: atan2(dy, dx))
        draw(unit, in: CGRect(x: 0, y: -width * 0.25, width: width, height: width * 0.5),
             context: context, alpha: CGFloat(Double(unit.attributes["alpha"] ?? "") ?? 1) * opacity)
        context.restoreGState()
    }
}

extension EditorController {
    func editSpriteText() {
        guard let index = workspace.selected, workspace.frame.units.indices.contains(index) else { return }
        let unit = workspace.frame.units[index]
        let id = workspace.frame.id
        let editor = SpriteTextEditor(unit: unit) { [weak self] text, color, font in
            guard let self, self.workspace.frame.id == id,
                  let index = self.workspace.frame.units.firstIndex(where: { $0.name == unit.name }) else { return }
            self.workspace.checkpoint()
            self.workspace.document.frames[self.workspace.index].units[index].attributes["nativeText"] = text
            self.workspace.document.frames[self.workspace.index].units[index].attributes["nativeTextColor"] = color
            self.workspace.document.frames[self.workspace.index].units[index].attributes["nativeTextFont"] = font
            self.workspace.notify()
        }
        editor.modalPresentationStyle = .overFullScreen
        present(editor, animated: true)
    }
}

private final class SpriteTextEditor: UIViewController, UIColorPickerViewControllerDelegate {
    let unit: SceneUnit
    let apply: (String, String, String) -> Void
    let input = UITextView()
    var color: UIColor
    var font: String

    init(unit: SceneUnit, apply: @escaping (String, String, String) -> Void) {
        self.unit = unit
        self.apply = apply
        color = SpriteText.color(unit)
        font = unit.attributes["nativeTextFont"] ?? "Roboto-Regular"
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        input.text = SpriteText.value(unit)
        input.accessibilityLabel = "Текст предмета"
        input.font = .systemFont(ofSize: 16)
        let bar = UIToolbar()
        bar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                     UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(hideKeyboard))]
        bar.sizeToFit()
        input.inputAccessoryView = bar
        let controls = UIStackView(arrangedSubviews: [
            button("Цвет") { [weak self] in self?.pickColor() },
            button("Шрифт") { [weak self] in self?.pickFont() },
            button("Отмена") { [weak self] in self?.dismiss(animated: true) },
            button("Применить") { [weak self] in self?.save() }
        ])
        controls.distribution = .fillEqually
        controls.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let panel = UIStackView(arrangedSubviews: [input, controls])
        panel.axis = .vertical
        panel.backgroundColor = .original(0x303030)
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.widthAnchor.constraint(equalTo: safe.widthAnchor, multiplier: 0.64),
            panel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            panel.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -6),
            input.heightAnchor.constraint(lessThanOrEqualToConstant: 150)
        ])
        let height = input.heightAnchor.constraint(equalToConstant: 150)
        height.priority = .defaultHigh
        height.isActive = true
    }

    private func button(_ title: String, action: @escaping () -> Void) -> UIButton {
        let result = UIButton(type: .system)
        result.setTitle(title, for: .normal)
        result.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return result
    }
    @objc private func hideKeyboard() { view.endEditing(true) }

    private func pickColor() {
        hideKeyboard()
        let picker = UIColorPickerViewController()
        picker.selectedColor = color
        picker.supportsAlpha = false
        picker.delegate = self
        present(picker, animated: true)
    }

    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        self.color = color
    }

    private func pickFont() {
        hideKeyboard()
        let alert = UIAlertController(title: "Выбрать шрифт", message: nil, preferredStyle: .alert)
        let names = ["Roboto-Regular", "HelveticaNeue", "Georgia", "CourierNewPSMT"]
        let descriptors = CTFontManagerCopyRegisteredFontDescriptors(.process, true) as? [CTFontDescriptor] ?? []
        let installed = descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
        for name in Array(Set(names + installed)).sorted() {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.font = name
                self?.input.font = UIFont(name: name, size: 16) ?? .systemFont(ofSize: 16)
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    private func save() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb = [r, g, b].map { Int((min(1, max(0, $0)) * 255).rounded()) }
        apply(String((input.text ?? "").prefix(2000)), String(format: "%02X%02X%02X", rgb[0], rgb[1], rgb[2]), font)
        dismiss(animated: true)
    }
}
