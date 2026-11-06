import UIKit
import ZIPFoundation

/// Portable native document, including imported sprites, backgrounds and sound.
enum CloudProjectArchive {
    struct Manifest: Codable {
        var version: Int
        var document: SceneDocument
        var artwork: [ArtworkDefinition]
    }
    static func pack(_ workspace: Workspace) throws -> URL {
        var document = workspace.document
        document.attributes.removeValue(forKey: "nativeSourceArchive")
        document.attributes.removeValue(forKey: "nativeArtworkDirectory")
        for index in document.frames.indices {
            if let id = document.frames[index].attributes["nativeBackgroundID"],
               let background = workspace.backgroundCatalog.first(where: { $0.id == id }), background.image.hasPrefix("@local/") {
                document.frames[index].attributes["nativeBackgroundImage"] = background.image
                document.frames[index].attributes.removeValue(forKey: "nativeBackgroundID")
            }
        }
        let used = Set(document.frames.flatMap { $0.units }.map { UnitIdentity.baseName($0.name) })
        let artwork = workspace.catalog.filter { used.contains($0.name) }
        let manifest = Manifest(version: 1, document: document, artwork: artwork)
        let source = try JSONEncoder().encode(manifest)
        var object = try JSONSerialization.jsonObject(with: source)
        var replacements: [String: String] = [:], assets: [(String, URL)] = []
        var total = 0
        func include(_ value: String, audio: Bool = false) throws -> String {
            if let replacement = replacements[value] { return replacement }
            guard audio || value.hasPrefix("@local/") else { return value }
            let path = audio ? "@local/" + value : value
            guard let url = workspace.artworkURL(path), FileManager.default.fileExists(atPath: url.path) else { throw CommunityError("Не найден файл проекта: \(value)") }
            total += try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard total <= 100 * 1024 * 1024 else { throw SceneReadError.resourceLimit }
            let name = "assets/\(assets.count)." + url.pathExtension
            let replacement = audio ? name : "@cloud/" + name
            assets.append((name, url)); replacements[value] = replacement
            return replacement
        }
        func walk(_ value: Any, key: String = "") throws -> Any {
            if let dict = value as? [String: Any] { return try dict.mapValuesWithKeys { try walk($1, key: $0) } }
            if let list = value as? [Any] { return try list.map { try walk($0) } }
            if let string = value as? String { return try include(string, audio: key == "nativeAudio") }
            return value
        }
        object = try walk(object)
        let data = try JSONSerialization.data(withJSONObject: object)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".animationproject")
        do {
            let archive = try Archive(url: url, accessMode: .create)
            try archive.addEntry(with: "project.json", type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) { offset, count in data.subdata(in: Int(offset)..<Int(offset)+count) }
            for (path, file) in assets {
                let bytes = try Data(contentsOf: file)
                try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(bytes.count), compressionMethod: .deflate) { offset, count in bytes.subdata(in: Int(offset)..<Int(offset)+count) }
            }
            return url
        } catch { try? FileManager.default.removeItem(at: url); throw error }
    }
    static func unpack(_ url: URL, into directory: URL) throws -> SceneDocument {
        let archive = try Archive(url: url, accessMode: .read)
        let entries = Array(archive)
        guard entries.count <= 4096, entries.allSatisfy({ $0.uncompressedSize <= 100 * 1024 * 1024 }), let manifest = archive["project.json"], manifest.uncompressedSize <= 16 * 1024 * 1024,
              entries.reduce(UInt64(0), { $0 + $1.uncompressedSize }) <= 100 * 1024 * 1024 else { throw SceneReadError.resourceLimit }
        var bytes = Data(); _ = try archive.extract(manifest) { bytes.append($0) }
        var created: [URL] = [], replacements: [String: String] = [:]
        do {
            for entry in entries where entry.path != "project.json" {
                guard entry.type == .file, entry.path.hasPrefix("assets/"), !entry.path.contains(".."), !entry.path.contains("\\"), entry.path.split(separator: "/").count == 2 else { throw SceneReadError.invalidScene }
                let file = UUID().uuidString + "." + URL(fileURLWithPath: entry.path).pathExtension
                let target = directory.appendingPathComponent(file)
                _ = try archive.extract(entry, to: target); created.append(target)
                replacements["@cloud/" + entry.path] = "@local/" + file
                replacements[entry.path] = file
            }
            func walk(_ value: Any) throws -> Any {
                if let dict = value as? [String: Any] { return try dict.mapValues { try walk($0) } }
                if let list = value as? [Any] { return try list.map { try walk($0) } }
                if let string = value as? String {
                    if let replacement = replacements[string] { return replacement }
                    guard !string.hasPrefix("@local/"), !string.hasPrefix("@cloud/") else { throw SceneReadError.invalidScene }
                }
                return value
            }
            let object = try walk(JSONSerialization.jsonObject(with: bytes))
            var result = try JSONDecoder().decode(Manifest.self, from: JSONSerialization.data(withJSONObject: object))
            guard result.version == 1, !result.document.frames.isEmpty, result.document.width > 0, result.document.height > 0,
                  result.document.width <= 16384, result.document.height <= 16384 else { throw SceneReadError.invalidScene }
            result.document.attributes.removeValue(forKey: "nativeSourceArchive")
            let id = UUID().uuidString
            let folder = directory.appendingPathComponent("ImportedArtwork/" + id)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); created.append(folder)
            try JSONEncoder().encode(result.artwork).write(to: folder.appendingPathComponent("catalog.json"), options: .atomic)
            result.document.attributes["nativeArtworkDirectory"] = id
            return result.document
        } catch { for path in created { try? FileManager.default.removeItem(at: path) }; throw error }
    }
}
private extension Dictionary where Key == String, Value == Any {
    func mapValuesWithKeys(_ transform: (String, Any) throws -> Any) rethrows -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in self { result[key] = try transform(key, value) }
        return result
    }
}
