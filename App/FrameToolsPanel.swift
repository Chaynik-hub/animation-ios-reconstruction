import UIKit

/// Geometry from frag_lay_frame_ops.xml and the Android panel-frame capture.
final class FrameToolsPanel: UIView {
    struct Command {
        let id: String
        let title: String
        let height: CGFloat
        let enabled: Bool
        let action: () -> Void
    }
    private var buttons: [String: UIButton] = [:]
    init(commands: [Command], accent: UIColor = .original(0x84d8ff), caption: String? = nil, identifier: String = "FrameToolsPanel", icons: [String:String] = [:]) {
        super.init(frame: .zero)
        accessibilityIdentifier = identifier
        backgroundColor = accent
        let scroll = UIScrollView()
        scroll.backgroundColor = .original(0x212121)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        if let caption {
            let label = UILabel(); label.text = caption; label.textColor = .white; label.backgroundColor = accent; label.textAlignment = .center; label.font = UIFont(name: "Roboto-Regular", size: 12)
            stack.addArrangedSubview(label); label.heightAnchor.constraint(equalToConstant: 27).isActive = true
        }
        for command in commands {
            let button = UIButton(type: .custom)
            var configuration = UIButton.Configuration.plain()
            if let url = Bundle.main.resourceURL?.appendingPathComponent("Content/Icons/" + (icons[command.id] ?? command.id) + ".png"),
               let image = UIImage(contentsOfFile: url.path) {
                configuration.image = image.resizedIcon(density: 2)
            }
            configuration.title = command.title.uppercased()
            configuration.imagePlacement = .top
            configuration.imagePadding = 0
            configuration.titleAlignment = .center
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
            configuration.baseForegroundColor = .original(0xdddddd)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { value in
                var attributes = value
                attributes.font = UIFont(name: "Roboto-Regular", size: command.id.hasPrefix("asset-state-") ? 30 : 12) ?? .systemFont(ofSize: 12)
                return attributes
            }
            button.configuration = configuration
            button.titleLabel?.numberOfLines = 2
            button.accessibilityIdentifier = command.id
            button.accessibilityLabel = command.title
            button.addAction(UIAction { _ in command.action() }, for: .touchUpInside)
            stack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: command.height).isActive = true
            buttons[command.id] = button
            setEnabled(command.enabled, for: command.id)
        }
    }
    func setEnabled(_ enabled: Bool, for id: String) {
        buttons[id]?.isEnabled = enabled
        buttons[id]?.alpha = enabled ? 1 : 0.2
    }
    func selectCommand(_ id: String) {
        for (name, button) in buttons {
            button.isSelected = name == id
            button.backgroundColor = name == id ? .original(0x00bd78) : .clear
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

