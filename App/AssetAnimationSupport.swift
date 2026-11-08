import UIKit

extension Workspace {
    var assetAnimations: [String:AssetAnimation.Configuration] {
        get { guard let text = document.attributes["nativeAssetAnimations"], let data = text.data(using: .utf8) else { return [:] }; return (try? JSONDecoder().decode([String:AssetAnimation.Configuration].self, from: data)) ?? [:] }
        set { if let data = try? JSONEncoder().encode(newValue) { document.attributes["nativeAssetAnimations"] = String(data: data, encoding: .utf8) } }
    }
    func states(for unit: SceneUnit) -> [Int] {
        guard let asset = catalog.first(where: { $0.name == UnitIdentity.baseName(unit.name) }) else { return [0] }
        return Array(Set(asset.parts.map { Int($0["state"] ?? "0") ?? 0 })).sorted()
    }
    func applyAssetAnimations(to frame: SceneFrame, tick: Int) -> SceneFrame {
        var output = frame
        let period = max(1, document.interframes + 1)
        for (name, config) in assetAnimations {
            let start = config.startID.flatMap { id in document.frames.firstIndex(where: { $0.id == id }) } ?? 0
            let end = document.frames.count - 1
            guard tick >= start * period, tick <= end * period + period - 1, let index = output.units.firstIndex(where: { $0.name == name }),
                  let state = AssetAnimation.state(in: states(for: output.units[index]), tick: tick - start * period, configuration: config) else { continue }
            output.units[index].attributes["state"] = String(state)
        }
        return output
    }
}

extension Workspace {
    func canInteract(with index:Int)->Bool {
        guard let name=latchedUnitName,let selected=frame.units.firstIndex(where:{$0.name==name}) else{return true}
        return UnitEditing.connected(in:frame,to:selected).contains(index)
    }
}
