import UIKit
import Security

struct CommunityProject: Decodable {
    let id: String
    let title: String
    let author: String
    let archive_path: String
    let average: Double?
    let votes: Int
}
struct CommunityComment: Decodable { let author: String; let body: String }
struct CommunityError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

// The app only contains a public API key. Ownership is enforced by Supabase RLS.
@MainActor enum CommunityAPI {
    private struct Session: Codable {
        let access_token: String
        let refresh_token: String
        let expires_at: Double?
        let expires_in: Double?
        let user: User
        struct User: Codable { let id: String }
    }
    private static var session: Session?
    private static var authentication: Task<Session, Error>?
    static var endpoint: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil,
              !raw.contains("$(") else { return nil }
        return url
    }
    private static var key: String {
        Bundle.main.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String ?? ""
    }
    static var configured: Bool { endpoint != nil && !key.isEmpty && !key.contains("$(") }
    private static var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "Animation.Supabase",
         kSecAttrAccount as String: endpoint?.host ?? ""]
    }
    private static func authenticate() async throws -> Session {
        if let authentication { return try await authentication.value }
        let task = Task<Session, Error> {
            if session == nil {
                var query = keychainQuery
                query[kSecReturnData as String] = true
                var result: CFTypeRef?
                if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
                    session = try? JSONDecoder().decode(Session.self, from: data)
                }
            }
            if let current = session, (current.expires_at ?? 0) > Date().timeIntervalSince1970 + 60 { return current }
            let path = session == nil ? "auth/v1/signup" : "auth/v1/token?grant_type=refresh_token"
            let body: [String: Any] = session.map { ["refresh_token": $0.refresh_token] } ?? [:]
            let data = try await raw(path, method: "POST", body: JSONSerialization.data(withJSONObject: body), token: nil)
            let decoded = try JSONDecoder().decode(Session.self, from: data)
            // Auth's expires_at can be absent in REST responses.
            let stored = Session(access_token: decoded.access_token, refresh_token: decoded.refresh_token,
                                 expires_at: decoded.expires_at ?? Date().timeIntervalSince1970 + (decoded.expires_in ?? 3600),
                                 expires_in: decoded.expires_in, user: decoded.user)
            let encoded = try JSONEncoder().encode(stored)
            var query = keychainQuery
            SecItemDelete(query as CFDictionary)
            query[kSecValueData as String] = encoded
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw CommunityError("Не удалось сохранить вход в облако.") }
            session = stored
            return stored
        }
        authentication = task
        defer { authentication = nil }
        return try await task.value
    }
    private static func raw(_ path: String, method: String = "GET", body: Data? = nil, token: String?, type: String = "application/json", prefer: String? = nil) async throws -> Data {
        guard configured, let endpoint, let url = URL(string: path, relativeTo: endpoint.appendingPathComponent("/")) else {
            throw CommunityError("Онлайн ещё не подключён. Нужны настройки Supabase в сборке.")
        }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = method; request.httpBody = body
        request.setValue(key, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        request.setValue(type, forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CommunityError("Нет ответа от облака.") }
        guard (200..<300).contains(response.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let detail = payload?["message"] as? String ?? payload?["error_description"] as? String ?? "Попробуйте ещё раз."
            throw CommunityError("Ошибка облака (\(response.statusCode)): \(detail)")
        }
        return data
    }
    static func request(_ path: String, method: String = "GET", values: [String: Any]? = nil, prefer: String? = nil) async throws -> Data {
        let user = try await authenticate()
        return try await raw(path, method: method, body: try values.map { try JSONSerialization.data(withJSONObject: $0) }, token: user.access_token, prefer: prefer)
    }
    static func list(offset: Int = 0) async throws -> [CommunityProject] {
        try JSONDecoder().decode([CommunityProject].self, from: await request("rest/v1/community_feed?select=*&order=created_at.desc,id.desc&limit=30&offset=\(offset)"))
    }
    static func comments(_ id: String) async throws -> [CommunityComment] {
        try JSONDecoder().decode([CommunityComment].self, from: await request("rest/v1/community_comments?select=author,body&project_id=eq.\(id)&order=created_at.desc&limit=100"))
    }
    static func project(_ id: String) async throws -> CommunityProject? {
        try JSONDecoder().decode([CommunityProject].self, from: await request("rest/v1/community_feed?select=*&id=eq.\(id)&limit=1")).first
    }
    static func rate(_ id: String, stars: Int) async throws {
        let user = try await authenticate()
        _ = try await request("rest/v1/community_ratings?on_conflict=project_id,user_id", method: "POST", values: ["project_id":id,"user_id":user.user.id,"stars":stars], prefer: "resolution=merge-duplicates")
    }
    static func comment(_ id: String, author: String, body: String) async throws {
        let user = try await authenticate()
        _ = try await request("rest/v1/community_comments", method: "POST", values: ["project_id":id,"user_id":user.user.id,"author":author,"body":body])
    }
    static func download(_ project: CommunityProject) async throws -> URL {
        let user = try await authenticate()
        let data = try await raw("storage/v1/object/animation-projects/" + project.archive_path, token: user.access_token)
        guard data.count <= 50 * 1024 * 1024 else { throw CommunityError("Проект превышает 50 МБ.") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".animationproject")
        try data.write(to: url, options: .atomic)
        return url
    }
    static func publish(workspace: Workspace, title: String, author: String) async throws {
        let url = try CloudProjectArchive.pack(workspace)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        guard data.count <= 50 * 1024 * 1024 else { throw CommunityError("Проект больше 50 МБ.") }
        let user = try await authenticate(), id = UUID().uuidString.lowercased()
        let path = user.user.id.lowercased() + "/" + id + ".animationproject"
        _ = try await raw("storage/v1/object/animation-projects/" + path, method: "POST", body: data, token: user.access_token, type: "application/zip")
        do {
            _ = try await request("rest/v1/community_projects", method: "POST", values: ["id":id,"owner_id":user.user.id,"title":title,"author":author,"archive_path":path])
        } catch {
            _ = try? await request("storage/v1/object/animation-projects", method: "DELETE", values: ["prefixes":[path]])
            throw error
        }
    }
    static func enterNickname(on controller: UIViewController, then action: @escaping (String) -> Void) {
        if let name = UserDefaults.standard.string(forKey: "community.nickname"), !name.isEmpty { action(name); return }
        let alert = UIAlertController(title: "Ваш ник", message: "Без регистрации", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Ник"; $0.autocorrectionType = .no }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Продолжить", style: .default) { [weak alert] _ in
            let name = String((alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
            guard !name.isEmpty else { return }
            UserDefaults.standard.set(name, forKey: "community.nickname"); action(name)
        })
        controller.present(alert, animated: true)
    }
}
