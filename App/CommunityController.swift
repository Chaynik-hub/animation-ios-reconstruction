import UIKit

/// Embedded in the existing landing pane; no navigation/modal shell of its own.
class OriginalListController: UIViewController {
    let scroll = UIScrollView(), stack = UIStackView()
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .original(0x3d3e4c)
        scroll.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(scroll)
        stack.axis = .vertical; stack.spacing = 1; stack.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor), scroll.topAnchor.constraint(equalTo: view.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor), stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
    }
    func clear() { stack.arrangedSubviews.forEach { $0.removeFromSuperview() } }
    func label(_ text: String) {
        let label = UILabel(); label.text = text; label.textColor = .white; label.numberOfLines = 0
        label.font = UIFont(name: "Roboto-Regular", size: 14) ?? .systemFont(ofSize: 14)
        let box = UIView(); label.translatesAutoresizingMaskIntoConstraints = false; box.addSubview(label)
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),label.trailingAnchor.constraint(equalTo: box.trailingAnchor,constant: -14),label.topAnchor.constraint(equalTo: box.topAnchor,constant: 12),label.bottomAnchor.constraint(equalTo: box.bottomAnchor,constant: -12)])
        stack.addArrangedSubview(box)
    }
    @discardableResult func row(_ text: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .custom); button.setTitle(text, for: .normal); button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.original(0xff9000), for: .highlighted); button.backgroundColor = .original(0x292b35)
        button.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 14) ?? .systemFont(ofSize: 14); button.titleLabel?.numberOfLines = 0
        button.contentHorizontalAlignment = .leading; button.contentEdgeInsets = UIEdgeInsets(top: 12,left: 14,bottom: 12,right: 14)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addAction(UIAction { _ in
            if AnimationSettings.bool("vibroPref", fallback: true) { UISelectionFeedbackGenerator().selectionChanged() }
            action()
        }, for: .touchUpInside); stack.addArrangedSubview(button); return button
    }
    func message(_ title: String, _ body: String? = nil) {
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true)
    }
}

final class CommunityController: OriginalListController {
    private var projects: [CommunityProject] = []
    private var selected: CommunityProject?
    private var comments: [CommunityComment] = []
    private var busy = false
    private var hasMore = false
    let openProject: (URL, String, Bool) -> Void
    init(openProject: @escaping (URL, String, Bool) -> Void) { self.openProject = openProject; super.init(nibName: nil,bundle: nil) }
    required init?(coder: NSCoder) { nil }
    override func viewDidLoad() { super.viewDidLoad(); reload() }
    private func render() {
        clear()
        if let item = selected {
            row("‹ Все мультфильмы") { [weak self] in self?.selected = nil; self?.render() }
            label(item.title + "\n" + item.author)
            label(item.average.map { String(format: "%.1f ★ · %d оценок",$0,item.votes) } ?? "Пока нет оценок")
            row("Смотреть") { [weak self] in self?.download(item, preview: true) }
            row("Скачать для редактирования") { [weak self] in self?.download(item, preview: false) }
            let stars = UIStackView(); stars.distribution = .fillEqually
            for value in 1...5 {
                let button = UIButton(type: .custom); button.setTitle("\(value) ★",for: .normal); button.setTitleColor(.original(0xff9000),for: .normal)
                button.titleLabel?.font = UIFont(name: "Roboto-Regular",size: 16); button.heightAnchor.constraint(equalToConstant: 48).isActive = true
                button.addAction(UIAction { [weak self] _ in self?.run { try await CommunityAPI.rate(item.id,stars:value); self?.message("Оценка сохранена"); self?.refreshDetail(item) } },for: .touchUpInside); stars.addArrangedSubview(button)
            }
            stack.addArrangedSubview(stars)
            row("Написать комментарий") { [weak self] in self?.writeComment(item) }
            if comments.isEmpty { label("Пока нет комментариев") }
            for comment in comments { label(comment.author + "\n" + comment.body) }
        } else {
            row("Обновить") { [weak self] in self?.reload() }
            if projects.isEmpty { label(busy ? "Загрузка…" : "Пока нет опубликованных мультфильмов") }
            for item in projects {
                row(item.title + "\n" + item.author + (item.average.map { String(format:" · %.1f ★",$0) } ?? "")) { [weak self] in self?.selected = item; self?.refreshDetail(item) }
            }
            if hasMore { row("Ещё мультфильмы") { [weak self] in self?.reload(more: true) } }
        }
    }
    func reload(more: Bool = false) {
        run {
            let batch = try await CommunityAPI.list(offset: more ? self.projects.count : 0)
            self.projects = more ? self.projects + batch : batch; self.hasMore = batch.count == 30
        }
    }
    private func refreshDetail(_ item: CommunityProject) {
        run { self.comments = try await CommunityAPI.comments(item.id) }
    }
    private func download(_ item: CommunityProject, preview: Bool) {
        run {
            let url = try await CommunityAPI.download(item)
            defer { try? FileManager.default.removeItem(at: url) }
            self.openProject(url,item.title,preview)
        }
    }
    private func writeComment(_ item: CommunityProject) {
        CommunityAPI.enterNickname(on: self) { [weak self] author in
            guard let self else { return }
            let alert = UIAlertController(title: "Комментарий",message:nil,preferredStyle:.alert)
            alert.addTextField { $0.placeholder = "Ваш комментарий" }
            alert.addAction(UIAlertAction(title: "Отмена",style:.cancel))
            alert.addAction(UIAlertAction(title: "Отправить",style:.default) { [weak alert, weak self] _ in
                let body = String((alert?.textFields?.first?.text ?? "").trimmingCharacters(in:.whitespacesAndNewlines).prefix(500))
                guard !body.isEmpty, let self else { return }
                self.run { try await CommunityAPI.comment(item.id,author:author,body:body); self.comments = try await CommunityAPI.comments(item.id) }
            }); self.present(alert,animated:true)
        }
    }
    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }; busy = true
        if isViewLoaded { view.isUserInteractionEnabled = false; render() }
        Task { @MainActor in
            defer { busy = false; view.isUserInteractionEnabled = true; render() }
            do { try await work() } catch { message("Онлайн",error.localizedDescription) }
        }
    }
}

extension EditorController {
    func publishOnline() {
        CommunityAPI.enterNickname(on: self) { [weak self] author in
            guard let self else { return }
            let alert = UIAlertController(title: "Опубликовать мультфильм", message: "Проект будет доступен для просмотра и редактирования другим пользователям под ником \(author).", preferredStyle: .alert)
            alert.addTextField { $0.text = self.titleOfScene }
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            alert.addAction(UIAlertAction(title: "Опубликовать",style:.default) { [weak self, weak alert] _ in
                let title = String((alert?.textFields?.first?.text ?? "").trimmingCharacters(in:.whitespacesAndNewlines).prefix(80))
                guard let self, !title.isEmpty else { return }
                self.view.isUserInteractionEnabled = false
                let indicator = UIActivityIndicatorView(style:.large); indicator.center = self.view.center; self.view.addSubview(indicator); indicator.startAnimating()
                Task { @MainActor in
                    defer { self.view.isUserInteractionEnabled = true; indicator.removeFromSuperview() }
                    do { try await CommunityAPI.publish(workspace:self.workspace,title:title,author:author); self.message("Опубликовано","Мультфильм появился в разделе «Загрузить → Онлайн».") }
                    catch { self.message("Не удалось опубликовать",error.localizedDescription) }
                }
            }); self.present(alert,animated:true)
        }
    }
}
