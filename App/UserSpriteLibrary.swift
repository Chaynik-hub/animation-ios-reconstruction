import Foundation
import UIKit
import ZIPFoundation

enum UserSpriteLibrary {
    struct Record: Codable { var definition: ArtworkDefinition; var archive: String }
    static func records(in directory: URL) -> [Record] {
        guard let data=try? Data(contentsOf:directory.appendingPathComponent("UserSprites/index.json")),data.count<=8*1024*1024 else{return []}
        return (try? JSONDecoder().decode([Record].self,from:data)) ?? []
    }
    static func definitions(in directory: URL) -> [ArtworkDefinition] {records(in:directory).map(\.definition)}
    @discardableResult static func importATI(_ source: URL, directory: URL) throws -> ArtworkDefinition {
        guard source.pathExtension.lowercased()=="ati" else{throw SceneReadError.invalidScene}
        let scoped=source.startAccessingSecurityScopedResource();defer{if scoped{source.stopAccessingSecurityScopedResource()}}
        guard (((try FileManager.default.attributesOfItem(atPath:source.path)[.size]) as? NSNumber)?.int64Value ?? Int64.max) <= 256*1024*1024 else{throw SceneReadError.resourceLimit}
        let archive=try Archive(url:source,accessMode:.read)
        var total=0
        func read(_ name:String,limit:Int=64*1024*1024)throws->Data {
            guard let entry=archive[name],entry.type == .file,UInt64(entry.uncompressedSize)<=UInt64(limit),total+Int(entry.uncompressedSize)<=256*1024*1024 else{throw SceneReadError.resourceLimit}
            var data=Data();_ = try archive.extract(entry){data.append($0)};total+=data.count;return data
        }
        let modelData=try read("model.xml",limit:16*1024*1024),assetsData=try read("assets.xml",limit:16*1024*1024)
        let model=try ArtworkXMLReader.read(model:modelData,assets:assetsData)
        let id=UUID().uuidString.lowercased(),relative="UserSprites/"+id,folder=directory.appendingPathComponent(relative,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var committed=false;defer{if !committed{try? FileManager.default.removeItem(at:folder)}}
        var parts:[[String:String]]=[]
        for (index,source) in model.parts.enumerated() {
            guard let name=source["bm"] else{throw SceneReadError.unsupportedElement("ATI artwork without a bitmap")}
            let data=try read(name)
            guard let image=UIImage(data:data),image.size.width>0,image.size.height>0,image.size.width*image.size.height<=32_000_000 else{throw SceneReadError.invalidScene}
            let filename="part-\(index).png";try data.write(to:folder.appendingPathComponent(filename),options:.atomic)
            var part=source;part["image"]="@local/"+relative+"/"+filename;parts.append(part)
        }
        guard !parts.isEmpty else{throw SceneReadError.invalidScene}
        var thumbnail:String?
        if archive["thumb.png"] != nil {
            let data=try read("thumb.png");guard UIImage(data:data) != nil else{throw SceneReadError.invalidScene}
            try data.write(to:folder.appendingPathComponent("thumb.png"),options:.atomic);thumbnail="@local/"+relative+"/thumb.png"
        }
        let name="@:imported_"+id.replacingOccurrences(of:"-",with:"")
        let title=source.deletingPathExtension().lastPathComponent
        let definition=ArtworkDefinition(name:name,points:model.points,parts:parts,thumbnail:thumbnail,defaultScale:1,titles:["ru":title,"en":title],packID:"@user",folderPath:[],catalogOrder:nil)
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
        let metadata=try JSONSerialization.data(withJSONObject:["title":title,"packID":"@user"])
        if let old=rewritten["native-item.json"]{try rewritten.remove(old)}
        try rewritten.addEntry(with:"native-item.json",type:.file,uncompressedSize:Int64(metadata.count),compressionMethod:.deflate,provider:{position,size in metadata.subdata(in:Int(position)..<Int(position)+size)})
        var index=records(in:directory);guard index.count<2000 else{throw SceneReadError.resourceLimit}
        index.append(Record(definition:definition,archive:relative+"/source.ati"))
        let encoded=try JSONEncoder().encode(index);guard encoded.count<=8*1024*1024 else{throw SceneReadError.resourceLimit}
        try encoded.write(to:directory.appendingPathComponent("UserSprites/index.json"),options:.atomic)
        committed=true;return definition
    }
}
