import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// Field names and geometry follow the shipped scene model.xml and Unit/UPoint metadata.
// Unknown attributes remain intact for forward-compatible editing; this is not yet full ATS support.
public struct Joint: Codable, Equatable, Sendable {
    public var id: Int
    public var x: Double
    public var y: Double
    public var parent: Int?
    public var attributes: [String: String]
}
public struct SceneUnit: Codable, Equatable, Sendable {
    public var name: String
    public var joints: [Joint]
    public var attributes: [String: String]
}
public struct SceneFrame: Codable, Equatable, Sendable {
    public var id: Int
    public var units: [SceneUnit]
    public var attributes: [String: String]
}
public struct SceneDocument: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var interframes: Int
    private struct MaskEntry: Codable {
        let name: String
        let mode: Int
    }

    public var squareMaskNames: Set<String> {
        get {
            guard let data = attributes["masks"]?.data(using: .utf8),
                  let entries = try? JSONDecoder().decode([MaskEntry].self, from: data) else { return [] }
            return Set(entries.filter { $0.mode == 1 }.map(\.name))
        }
        set {
            let entries = newValue.sorted().map { MaskEntry(name: $0, mode: 1) }
            attributes["masks"] = entries.isEmpty ? nil :
                (try? JSONEncoder().encode(entries)).map { String(decoding: $0, as: UTF8.self) }
        }
    }

    public var interpolatesPlayback: Bool { attributes["no_interpolation"] != "true" }
    public var ticksPerKeyframe: Int {
        if !interpolatesPlayback {
            return 1 + min(9, max(0, attributes["no_interpolation_frames"].flatMap(Int.init) ?? 0))
        }
        return max(0, min(119, interframes)) + 1
    }
    public var frames: [SceneFrame]
    public var attributes: [String: String]
}
public enum SceneReadError: Error, Equatable {
    case malformedXML
    case invalidScene
    case invalidJoint
    case resourceLimit
    case unsupportedElement(String)
}

public enum SceneXMLReader {
    public static func read(_ data: Data) throws -> SceneDocument {
        guard data.count <= 64 * 1024 * 1024 else { throw SceneReadError.resourceLimit }
        let delegate = Reader()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.failure == nil else { throw delegate.failure ?? .malformedXML }
        guard let document = delegate.document, !document.frames.isEmpty else { throw SceneReadError.invalidScene }
        return document
    }
    private final class Reader: NSObject, XMLParserDelegate {
        var document: SceneDocument?
        var frame: SceneFrame?
        var unit: SceneUnit?
        var failure: SceneReadError?
        var points = 0
        func reject(_ error: SceneReadError, _ parser: XMLParser) { failure = error; parser.abortParsing() }
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String:String]) {
            switch name {
            case "scene":
                guard document == nil, let w = Double(a["w"] ?? ""), let h = Double(a["h"] ?? ""), w.isFinite, h.isFinite, w > 0, h > 0 else { reject(.invalidScene, parser); return }
                document = SceneDocument(width: w, height: h, interframes: Int(a["interframes"] ?? "0") ?? 0, frames: [], attributes: a)
            case "frame":
                guard document != nil, frame == nil, let id = Int(a["id"] ?? ""), document!.frames.count < 100_000 else { reject(.invalidScene, parser); return }
                frame = SceneFrame(id: id, units: [], attributes: a)
            case "unit":
                guard frame != nil, unit == nil, let name = a["name"] else { reject(.invalidScene, parser); return }
                unit = SceneUnit(name: name, joints: [], attributes: a)
            case "point":
                guard unit != nil, let id = Int(a["id"] ?? ""), let x = Double(a["x"] ?? ""), let y = Double(a["y"] ?? ""), x.isFinite, y.isFinite else { reject(.invalidJoint, parser); return }
                points += 1
                guard points < 1_000_000 else { reject(.resourceLimit, parser); return }
                unit!.joints.append(Joint(id: id, x: x, y: y, parent: a["par"].flatMap(Int.init), attributes: a))
            default:
                // Refuse unsupported data rather than silently drop animation/effect information.
                reject(.unsupportedElement(name), parser)
            }
        }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            if name == "unit", let value = unit { frame?.units.append(value); unit = nil }
            if name == "frame", let value = frame { document?.frames.append(value); frame = nil }
        }
        func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { reject(.malformedXML, parser) }
        func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { reject(.malformedXML, parser) }
    }
}
