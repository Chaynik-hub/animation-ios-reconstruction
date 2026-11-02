import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct ArtworkModel:Equatable,Sendable {
    public let name:String
    public let points:[[String:String]]
    public let parts:[[String:String]]
}
public enum ArtworkXMLReader {
    public static func read(model:Data,assets:Data)throws->ArtworkModel {
        let geometry=try parse(model,child:"point"),pictures=try parse(assets,child:"edgeAsset")
        guard !geometry.elements.isEmpty,!pictures.elements.isEmpty,
              let name=pictures.name ?? geometry.name,!name.isEmpty else{throw SceneReadError.invalidJoint}
        var ids=Set<Int>()
        for point in geometry.elements {
            guard let id=Int(point["id"] ?? ""),ids.insert(id).inserted,
                  let x=Double(point["x"] ?? ""),let y=Double(point["y"] ?? ""),x.isFinite,y.isFinite else{throw SceneReadError.invalidJoint}
        }
        for edge in pictures.elements {
            guard let start=Int(edge["start"] ?? ""),let end=Int(edge["end"] ?? ""),ids.contains(start),ids.contains(end) else{throw SceneReadError.invalidJoint}
        }
        return ArtworkModel(name:name,points:geometry.elements,parts:pictures.elements)
    }
    private static func parse(_ data:Data,child:String)throws->Reader {
        guard data.count<=16*1024*1024 else{throw SceneReadError.resourceLimit}
        let delegate=Reader(child:child),parser=XMLParser(data:data)
        parser.shouldResolveExternalEntities=false;parser.delegate=delegate
        guard parser.parse(),delegate.failure==nil,delegate.sawRoot else{throw delegate.failure ?? SceneReadError.malformedXML}
        return delegate
    }
    private final class Reader:NSObject,XMLParserDelegate {
        let child:String
        var name:String?,elements:[[String:String]]=[],failure:SceneReadError?,depth=0,sawRoot=false
        init(child:String){self.child=child}
        func parser(_ parser:XMLParser,didStartElement element:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) {
            if depth==0,element=="unit",!sawRoot {sawRoot=true;name=attributes["name"]}
            else if depth==1,element==child {elements.append(attributes);if elements.count>100_000{failure = .resourceLimit;parser.abortParsing()}}
            else {failure = .unsupportedElement(element);parser.abortParsing()}
            depth+=1
        }
        func parser(_ parser:XMLParser,didEndElement:String,namespaceURI:String?,qualifiedName:String?){depth-=1}
        func parser(_ parser:XMLParser,foundInternalEntityDeclarationWithName:String,value:String?){failure = .malformedXML;parser.abortParsing()}
        func parser(_ parser:XMLParser,foundExternalEntityDeclarationWithName:String,publicID:String?,systemID:String?){failure = .malformedXML;parser.abortParsing()}
    }
}
