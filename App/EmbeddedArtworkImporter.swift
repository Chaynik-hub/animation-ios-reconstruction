import Foundation
import ZIPFoundation

/// Embedded ATS items are nested ATI archives; original asset names (including @:)
/// come from assets.xml and remain unchanged in the scene model.
enum EmbeddedArtworkImporter {
    static func importFrom(archive:Archive,directory:URL)throws->String? {
        let entries=archive.filter{$0.path.lowercased().hasSuffix(".ati") && !$0.path.hasPrefix("__MACOSX/")}
        guard !entries.isEmpty else{return nil}
        guard entries.count<=512 else{throw SceneReadError.resourceLimit}
        let id=UUID().uuidString,relative="ImportedArtwork/"+id
        let folder=directory.appendingPathComponent(relative,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var total=UInt64(0),definitions:[ArtworkDefinition]=[]
        func data(_ archive:Archive,_ name:String,limit:UInt64=64*1024*1024)throws->Data {
            guard let entry=archive[name] else{throw SceneReadError.invalidScene}
            guard entry.type == .file,entry.uncompressedSize<=limit,total+entry.uncompressedSize<=512*1024*1024 else{throw SceneReadError.resourceLimit}
            total+=entry.uncompressedSize
            var bytes=Data()
            _ = try archive.extract(entry){part in
                guard UInt64(bytes.count+part.count)<=limit else{throw SceneReadError.resourceLimit};bytes.append(part)
            }
            return bytes
        }
        for (index,entry) in entries.enumerated() {
            let itemURL=folder.appendingPathComponent("item-\(index).ati")
            try data(archive,entry.path).write(to:itemURL,options:.atomic)
            let item=try Archive(url:itemURL,accessMode:.read)
            let model=try ArtworkXMLReader.read(model:data(item,"model.xml",limit:16*1024*1024),assets:data(item,"assets.xml",limit:16*1024*1024))
            let partFolder=folder.appendingPathComponent("item-\(index)",isDirectory:true)
            try FileManager.default.createDirectory(at:partFolder,withIntermediateDirectories:true)
            var parts:[[String:String]]=[]
            for (partIndex,source) in model.parts.enumerated() {
                // Match original bitmap renderer: absent declared bitmaps are skipped.
                guard let name=source["bm"],item[name] != nil else{continue}
                let file="part-\(partIndex).png",destination=partFolder.appendingPathComponent(file)
                try data(item,name).write(to:destination,options:.atomic)
                var part=source;part["image"]="@local/"+relative+"/item-\(index)/"+file;parts.append(part)
            }
            var thumbnail:String?
            if item["thumb.png"] != nil {
                try data(item,"thumb.png").write(to:partFolder.appendingPathComponent("thumb.png"),options:.atomic)
                thumbnail="@local/"+relative+"/item-\(index)/thumb.png"
            }
            definitions.append(ArtworkDefinition(name:model.name,points:model.points,parts:parts,thumbnail:thumbnail,defaultScale:1,titles:nil))
        }
        try JSONEncoder().encode(definitions).write(to:folder.appendingPathComponent("catalog.json"),options:.atomic)
        return id
    }
}
