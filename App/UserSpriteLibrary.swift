import Foundation
import UIKit
import ZIPFoundation

enum UserSpriteLibrary {
    private enum ImportError: LocalizedError {
        case missingEntry(String), noSupportedSprites
        var errorDescription: String? {
            switch self {
            case .missingEntry(let path): return "В архиве нет файла «\(path)»."
            case .noSupportedSprites: return "В паке нет спрайтов, которые iOS-редактор может отобразить."
            }
        }
    }
    struct Record: Codable { var definition: ArtworkDefinition; var archive: String }
    static func records(in directory: URL) -> [Record] {
        guard let data=try? Data(contentsOf:directory.appendingPathComponent("UserSprites/index.json")) else{return []}
        return (try? JSONDecoder().decode([Record].self,from:data)) ?? []
    }
    static func definitions(in directory: URL) -> [ArtworkDefinition] {records(in:directory).map(\.definition)}
    @discardableResult static func importFile(_ source: URL, directory: URL) throws -> Int {
        if source.pathExtension.lowercased() == "atp" {
            return try importPack(source, directory: directory)
        } else {
            _ = try importATI(source, directory: directory)
            return 0
        }
    }

    private static func importPack(_ source: URL, directory: URL) throws -> Int {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let files = FileManager.default
        let archive = try Archive(url: source, accessMode: .read)
        let entries = archive.filter { entry in
            entry.type == .file && entry.path.lowercased().hasSuffix(".ati") &&
            !entry.path.hasPrefix("__MACOSX/") && !(entry.path as NSString).lastPathComponent.hasPrefix("._")
        }
        let current = records(in: directory)
        guard !entries.isEmpty else { throw SceneReadError.invalidScene }

        let staging = files.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: staging) }
        let metadata = PackManifest()
        if let entry = archive["manifest.xml"], entry.uncompressedSize <= 2 * 1024 * 1024 {
            var data = Data()
            _ = try archive.extract(entry) { data.append($0) }
            let parser = XMLParser(data: data)
            parser.delegate = metadata
            guard parser.parse() else { throw SceneReadError.malformedXML }
        }
        func readMetadata(_ path: String, limit: Int) throws -> Data? {
            guard let entry = archive[path], entry.type == .file, entry.uncompressedSize <= UInt64(limit) else { return nil }
            var data = Data()
            _ = try archive.extract(entry) { data.append($0) }
            return data
        }
        let meta = try readMetadata("meta.txt", limit: 1024 * 1024)
        let fields = meta.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
        let embeddedTitle = (fields?["mHumanName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = embeddedTitle.flatMap { $0.isEmpty ? nil : $0 } ?? source.deletingPathExtension().lastPathComponent
        var cover: Data?
        for path in ["logo.png", "thumb_hdpi.png", "thumb.png", "icon.png", "cover.png"] {
            guard let bytes = try readMetadata(path, limit: 16 * 1024 * 1024),
                  let image = UIImage(data: bytes), image.size.width * image.size.height <= 16_000_000 else { continue }
            cover = bytes
            break
        }
        var skipped = 0
        var additions: [Record] = []
        let pack = "@pack:\(UUID().uuidString):\(title)"
        for (order, entry) in entries.enumerated() {
            let components = entry.path.split(separator: "/").map(String.init)
            guard let filename = components.last else { continue }
            let item = staging.appendingPathComponent(filename)
            _ = try archive.extract(entry, to: item)
            defer { try? files.removeItem(at: item) }
            let shortName = (filename as NSString).deletingPathExtension
            do {
                try importATI(item, directory: staging, packID: pack,
                              folderPath: metadata.folders[shortName] ?? Array(components.dropLast().filter { $0 != "items" }),
                              order: order, defaultScale: metadata.scale, manifestFolders: metadata.folders,
                              collect: { additions.append($0) })
            } catch is ImportError {
                skipped += 1
            } catch SceneReadError.unsupportedElement(_) {
                skipped += 1
            } catch SceneReadError.resourceLimit {
                skipped += 1
            }
        }
        guard !additions.isEmpty else { throw ImportError.noSupportedSprites }
        guard additions.count + skipped == entries.count else { throw SceneReadError.invalidScene }
        if let cover, let first = additions.first {
            let folder = (first.archive as NSString).deletingLastPathComponent
            let path = folder + "/pack-cover.png"
            try cover.write(to: staging.appendingPathComponent(path), options: .atomic)
            for index in additions.indices { additions[index].definition.packCover = "@local/" + path }
        }
        let root = directory.appendingPathComponent("UserSprites", isDirectory: true)
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        var moved: [URL] = []
        var committed = false
        defer { if !committed { for url in moved { try? files.removeItem(at: url) } } }
        for record in additions {
            let folder = (record.archive as NSString).deletingLastPathComponent
            let destination = directory.appendingPathComponent(folder)
            try files.moveItem(at: staging.appendingPathComponent(folder), to: destination)
            moved.append(destination)
        }
        let index = try JSONEncoder().encode(current + additions)
        try index.write(to: root.appendingPathComponent("index.json"), options: .atomic)
        committed = true
        return skipped
    }

    private final class PackManifest: NSObject, XMLParserDelegate {
        var folders: [String: [String]] = [:]
        var scale = 1.0
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            if let raw = attributes["def_scale"], let value = Double(raw), value.isFinite, value > 0 {
                scale = value
            }
            if elementName == "item", let name = attributes["sname"] {
                folders[name] = (attributes["set"] ?? "").replacingOccurrences(of: "\\", with: "/")
                    .split(separator: "/").map(String.init)
            }
        }
    }

    @discardableResult static func importATI(_ source: URL, directory: URL, packID: String = "@user", folderPath: [String] = [], order: Int? = nil, defaultScale: Double = 1, manifestFolders: [String: [String]] = [:], collect: ((Record) -> Void)? = nil) throws -> ArtworkDefinition {
        guard source.pathExtension.lowercased()=="ati" else{throw SceneReadError.invalidScene}
        let scoped=source.startAccessingSecurityScopedResource();defer{if scoped{source.stopAccessingSecurityScopedResource()}}
        guard collect != nil || (((try FileManager.default.attributesOfItem(atPath:source.path)[.size]) as? NSNumber)?.int64Value ?? Int64.max) <= 256*1024*1024 else{throw SceneReadError.resourceLimit}
        let archive=try Archive(url:source,accessMode:.read)
        func read(_ name:String,limit:Int=64*1024*1024)throws->Data {
            guard let entry=archive[name],entry.type == .file else { throw ImportError.missingEntry(name) }
            guard UInt64(entry.uncompressedSize)<=UInt64(limit) else{throw SceneReadError.resourceLimit}
            var data=Data();_ = try archive.extract(entry){data.append($0)};return data
        }
        let modelData=try read("model.xml",limit:16*1024*1024),assetsData=try read("assets.xml",limit:16*1024*1024)
        let model=try ArtworkXMLReader.read(model:modelData,assets:assetsData)
        let id=UUID().uuidString.lowercased(),relative="UserSprites/"+id,folder=directory.appendingPathComponent(relative,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var committed=false;defer{if !committed{try? FileManager.default.removeItem(at:folder)}}
        var parts:[[String:String]]=[]
        for (index,source) in model.parts.enumerated() {
            guard let name = source["bm"] else {
                if packID.hasPrefix("@pack:") { continue }
                throw SceneReadError.unsupportedElement("ATI artwork without a bitmap")
            }
            if packID.hasPrefix("@pack:"), archive[name] == nil { continue }
            let data=try read(name)
            guard let image=UIImage(data:data),image.size.width>0,image.size.height>0,image.size.width*image.size.height<=32_000_000 else{throw SceneReadError.invalidScene}
            let filename="part-\(index).png";try data.write(to:folder.appendingPathComponent(filename),options:.atomic)
            var part=source;part["image"]="@local/"+relative+"/"+filename;parts.append(part)
        }
        guard !parts.isEmpty else{throw SceneReadError.unsupportedElement("ATI without available bitmap artwork")}
        var thumbnail:String?
        if archive["thumb.png"] != nil {
            let data=try read("thumb.png");guard UIImage(data:data) != nil else{throw SceneReadError.invalidScene}
            try data.write(to:folder.appendingPathComponent("thumb.png"),options:.atomic);thumbnail="@local/"+relative+"/thumb.png"
        }
        let name="@:imported_"+id.replacingOccurrences(of:"-",with:"")
        let title=source.deletingPathExtension().lastPathComponent
        let shortName = model.name.split(separator: ":", maxSplits: 1).last.map(String.init) ?? model.name
        let definition=ArtworkDefinition(name:name,points:model.points,parts:parts,thumbnail:thumbnail,defaultScale:defaultScale,titles:["ru":title,"en":title],packID:packID,folderPath:manifestFolders[shortName] ?? folderPath,catalogOrder:order)
        let copy=folder.appendingPathComponent("source.ati");try FileManager.default.copyItem(at:source,to:copy)
        let rewritten=try Archive(url:copy,accessMode:.update)
        func renameRoot(_ data:Data)throws->Data {
            guard let text=String(data:data,encoding:.utf8) else{throw SceneReadError.malformedXML}
            let expression=try NSRegularExpression(pattern:"<unit\\b[^>]*>")
            guard let match=expression.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)),let range=Range(match.range,in:text) else{throw SceneReadError.invalidScene}
            let tag=String(text[range]);let names=try NSRegularExpression(pattern:"\\s+name\\s*=\\s*(\"[^\"]*\"|'[^']*')")
            let clean=names.stringByReplacingMatches(in:tag,range:NSRange(tag.startIndex...,in:tag),withTemplate:"")
            let root=clean.replacingOccurrences(of:"<unit",with:"<unit name=\""+name+"\"")
            return Data(text.replacingCharacters(in:range,with:root).utf8)
        }
        let newModel=try renameRoot(modelData),newAssets=try renameRoot(assetsData)
        guard try ArtworkXMLReader.read(model:newModel,assets:newAssets).name==name else{throw SceneReadError.invalidScene}
        for (path,data) in [("model.xml",newModel),("assets.xml",newAssets)] {
            if let existing=rewritten[path]{try rewritten.remove(existing)}
            try rewritten.addEntry(with:path,type:.file,uncompressedSize:Int64(data.count),compressionMethod:.deflate,provider:{position,size in data.subdata(in:Int(position)..<Int(position)+size)})
        }
        let metadata=try JSONSerialization.data(withJSONObject:["title":title,"packID":packID])
        if let old=rewritten["native-item.json"]{try rewritten.remove(old)}
        try rewritten.addEntry(with:"native-item.json",type:.file,uncompressedSize:Int64(metadata.count),compressionMethod:.deflate,provider:{position,size in metadata.subdata(in:Int(position)..<Int(position)+size)})
        let record = Record(definition: definition, archive: relative + "/source.ati")
        if let collect {
            collect(record)
        } else {
            let encoded = try JSONEncoder().encode(records(in: directory) + [record])
            try encoded.write(to: directory.appendingPathComponent("UserSprites/index.json"), options: .atomic)
        }
        committed=true;return definition
    }
}
