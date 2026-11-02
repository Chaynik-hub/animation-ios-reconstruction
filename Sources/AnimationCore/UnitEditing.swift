import Foundation

public enum UnitEditing {
    public static func descendants(in frame: SceneFrame, of index: Int) -> Set<Int> {
        guard frame.units.indices.contains(index) else { return [] }
        var result: Set<Int> = [index], pending = [index]
        while let parent = pending.popLast() {
            for i in frame.units.indices where !result.contains(i) {
                if FrameManipulation.attachment(frame.units[i])?.0 == frame.units[parent].name { result.insert(i); pending.append(i) }
            }
        }
        return result
    }
    public static func connected(in frame: SceneFrame, to index: Int) -> Set<Int> {
        guard frame.units.indices.contains(index) else { return [] }
        var root = index, visited: Set<Int> = [index]
        while let name = FrameManipulation.attachment(frame.units[root])?.0,
              let parent = frame.units.firstIndex(where: { $0.name == name }), visited.insert(parent).inserted { root = parent }
        return descendants(in: frame, of: root)
    }
    public static func remove(_ index: Int, from frame: inout SceneFrame) {
        let victims = descendants(in: frame, of: index)
        for i in victims.sorted(by: >) { frame.units.remove(at: i) }
    }
    @discardableResult public static func detach(_ index: Int, in frame: inout SceneFrame) -> Bool {
        guard frame.units.indices.contains(index), FrameManipulation.attachment(frame.units[index]) != nil,
              let base = frame.units[index].joints.firstIndex(where: { $0.attributes["base"] == "true" }) else { return false }
        frame.units[index].joints[base].attributes.removeValue(forKey: "attached")
        for i in descendants(in: frame, of: index) {
            for j in frame.units[i].joints.indices { frame.units[i].joints[j].x += 25; frame.units[i].joints[j].y += 25 }
        }
        return true
    }
    public static func orderedIndices(in frame: SceneFrame) -> [Int] {
        frame.units.indices.sorted { a,b in
            let aa = Int(frame.units[a].attributes["arrange"] ?? "") ?? a
            let bb = Int(frame.units[b].attributes["arrange"] ?? "") ?? b
            return aa == bb ? a < b : aa < bb
        }
    }
    public static func snapshot(in frame: SceneFrame, selected: Int) -> [SceneUnit] {
        let group = connected(in: frame, to: selected)
        return orderedIndices(in: frame).filter { group.contains($0) }.map { frame.units[$0] }
    }
    /// Copies the entire connected assembly and rewrites links to the new names.
    @discardableResult public static func paste(_ units: [SceneUnit], into frame: inout SceneFrame) -> [Int] {
        guard !units.isEmpty, Set(units.map(\.name)).count == units.count else { return [] }
        var reservation = frame, names: [String:String] = [:]
        for unit in units {
            var copy = unit; copy.name = UnitIdentity.inserting(unit.name, in: reservation)
            names[unit.name] = copy.name; reservation.units.append(copy)
        }
        let start = frame.units.count
        let arrange = frame.units.indices.map { Int(frame.units[$0].attributes["arrange"] ?? "") ?? $0 }.max() ?? -1
        guard arrange <= Int.max - units.count else { return [] }
        for (offset, unit) in units.enumerated() {
            var copy = unit; copy.name = names[unit.name]!
            copy.attributes["arrange"] = String(arrange + offset + 1)
            if let link = FrameManipulation.attachment(copy), let base = copy.joints.firstIndex(where: { $0.attributes["base"] == "true" }) {
                if let renamed = names[link.0] { copy.joints[base].attributes["attached"] = renamed + "&" + String(link.1) }
                else { copy.joints[base].attributes.removeValue(forKey: "attached") }
            }
            frame.units.append(copy)
        }
        return Array(start..<frame.units.count)
    }
    @discardableResult public static func rearrange(_ index: Int, forward: Bool, in frame: inout SceneFrame) -> Bool {
        let order = orderedIndices(in: frame)
        guard let position = order.firstIndex(of: index) else { return false }
        let next = position + (forward ? 1 : -1)
        guard order.indices.contains(next) else { return false }
        for (rank, i) in order.enumerated() { frame.units[i].attributes["arrange"] = String(rank) }
        frame.units[index].attributes["arrange"] = String(next)
        frame.units[order[next]].attributes["arrange"] = String(position)
        return true
    }
}
