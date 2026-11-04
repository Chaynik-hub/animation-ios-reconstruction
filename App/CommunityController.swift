import UIKit

private struct CommunityProject: Decodable {
    let id: String
    let title: String
    let author: String
    let average: Double?
    let votes: Int
}

private struct CommunityComment: Decodable {
    let author: String
    let body: String
}

private struct CommunityError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

enum CommunityAPI {
    private static let nicknameKey = "community.nickname"

    static var endpoint: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AnimationCommunityURL") as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }

    private static var deviceToken: String {
        let key = "community.device"
        if let token = UserDefaults.standard.string(forKey: key) { return token }
        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: key)
        return token
    }

    static func request(_ path: String, method: String = "GET", body: Data? = nil, headers: [String: String] = [:]) async throws -> Data {
        guard let endpoint else { throw CommunityError("Сервер онлайн-проектов ещё не настроен.") }
        let url = path.split(separator: "/").reduce(endpoint) { $0.appendingPathComponent(String($1)) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer " + deviceToken, forHTTPHeaderField: "Authorization")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw CommunityError("Сервер не смог выполнить запрос.")
        }
        return data
    }

    static func send(_ path: String, values: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: values)
        _ = try await request(path, method: "POST", body: body, headers: ["Content-Type": "application/json"])
    }

    @MainActor static func enterNickname(on controller: UIViewController, then action: @escaping (String) -> Void) {
        if let name = UserDefaults.standard.string(forKey: nicknameKey) { action(name); return }
        let alert = UIAlertController(title: "Ваш ник", message: "Он будет виден рядом с вашими проектами и комментариями.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Ник" }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Продолжить", style: .default) { [weak alert] _ in
            let name = String((alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
            guard !name.isEmpty else { return }
            UserDefaults.standard.set(name, forKey: nicknameKey)
            action(name)
        })
        controller.present(alert, animated: true)
    }
}

final class CommunityController: UITableViewController {
    private let project: CommunityProject?
    private let openProject: (URL) -> Void
    private var projects: [CommunityProject] = []
    private var comments: [CommunityComment] = []
    private var loading = false

    init(openProject: @escaping (URL) -> Void) {
        self.project = nil
        self.openProject = openProject
        super.init(style: .insetGrouped)
    }

    private init(project: CommunityProject, openProject: @escaping (URL) -> Void) {
        self.project = project
        self.openProject = openProject
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = project?.title ?? "Онлайн-проекты"
        overrideUserInterfaceStyle = .dark
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadFeed))
        if project == nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
        }
        reloadFeed()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if project == nil, !projects.isEmpty { reloadFeed() }
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func reloadFeed() {
        run {
            if let project = self.project {
                let data = try await CommunityAPI.request("projects/\(project.id)/comments")
                self.comments = try JSONDecoder().decode([CommunityComment].self, from: data)
            } else {
                let data = try await CommunityAPI.request("projects")
                self.projects = try JSONDecoder().decode([CommunityProject].self, from: data)
            }
            self.tableView.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        project == nil ? projects.count : 3 + comments.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let row = indexPath.row
        if project == nil {
            let item = projects[row]
            cell.textLabel?.text = item.title
            let rating = item.average.map { String(format: "%.1f ★ (%d)", $0, item.votes) } ?? "Без оценок"
            cell.detailTextLabel?.text = "\(item.author) · \(rating)"
            cell.accessoryType = .disclosureIndicator
        } else if row < 3 {
            cell.textLabel?.text = ["Открыть в редакторе", "Поставить оценку", "Написать комментарий"][row]
        } else {
            let comment = comments[row - 3]
            cell.textLabel?.text = comment.author
            cell.detailTextLabel?.text = comment.body
            cell.detailTextLabel?.numberOfLines = 0
            cell.selectionStyle = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = indexPath.row
        guard let project else {
            navigationController?.pushViewController(CommunityController(project: projects[row], openProject: openProject), animated: true)
            return
        }
        switch row {
        case 0:
            run {
                let data = try await CommunityAPI.request("projects/\(project.id)/archive")
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ats")
                try data.write(to: url, options: .atomic)
                self.dismiss(animated: true) { self.openProject(url) }
            }
        case 1:
            let alert = UIAlertController(title: "Оценка проекта", message: nil, preferredStyle: .alert)
            for stars in (1...5).reversed() {
                alert.addAction(UIAlertAction(title: String(repeating: "★", count: stars), style: .default) { [weak self] _ in
                    self?.run {
                        try await CommunityAPI.send("projects/\(project.id)/rating", values: ["stars": stars])
                        self?.message("Оценка сохранена")
                    }
                })
            }
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            present(alert, animated: true)
        case 2:
            CommunityAPI.enterNickname(on: self) { [weak self] name in
                self?.writeComment(project, as: name)
            }
        default: break
        }
    }

    private func writeComment(_ project: CommunityProject, as author: String) {
        let alert = UIAlertController(title: "Комментарий", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Ваш комментарий" }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Отправить", style: .default) { [weak self, weak alert] _ in
            let body = String((alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
            guard !body.isEmpty, let self else { return }
            self.run {
                try await CommunityAPI.send("projects/\(project.id)/comments", values: ["author": author, "body": body])
                let data = try await CommunityAPI.request("projects/\(project.id)/comments")
                self.comments = try JSONDecoder().decode([CommunityComment].self, from: data)
                self.tableView.reloadData()
            }
        })
        present(alert, animated: true)
    }

    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        guard !loading else { return }
        loading = true
        Task {
            defer { loading = false }
            do { try await work() }
            catch { message(error.localizedDescription) }
        }
    }

    private func message(_ title: String) {
        guard view.window != nil, presentedViewController == nil else { return }
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension EditorController {
    func publishOnline() {
        guard CommunityAPI.endpoint != nil else {
            message("Онлайн-проекты", "Сервер ещё не настроен.")
            return
        }
        CommunityAPI.enterNickname(on: self) { [weak self] author in
            guard let self else { return }
            let alert = UIAlertController(title: "Опубликовать проект", message: "Проект будет виден другим пользователям под ником \(author).", preferredStyle: .alert)
            alert.addTextField { $0.text = self.titleOfScene }
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            alert.addAction(UIAlertAction(title: "Опубликовать", style: .default) { [weak self, weak alert] _ in
                let title = String((alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
                guard let self, !title.isEmpty else { return }
                self.perform {
                    let archive = try self.workspace.saveATS()
                    defer { try? FileManager.default.removeItem(at: archive) }
                    let size = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 16 * 1024 * 1024 else { throw CommunityError("Проект больше 16 МБ.") }
                    let data = try Data(contentsOf: archive)
                    let safe = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
                    let headers = [
                        "X-Project-Title": title.addingPercentEncoding(withAllowedCharacters: safe) ?? "",
                        "X-Project-Author": author.addingPercentEncoding(withAllowedCharacters: safe) ?? "",
                        "Content-Type": "application/zip"
                    ]
                    Task {
                        do {
                            _ = try await CommunityAPI.request("projects", method: "POST", body: data, headers: headers)
                            self.message("Проект опубликован", "Он появится в разделе «Онлайн».")
                        } catch {
                            self.message("Не удалось опубликовать", error.localizedDescription)
                        }
                    }
                }
            })
            self.present(alert, animated: true)
        }
    }
}
