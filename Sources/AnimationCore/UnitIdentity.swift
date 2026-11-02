import Foundation

/// Frame.generateUnitNameWithNumber/getNumberForInsertingItem.
public enum UnitIdentity {
    public static func baseName(_ name:String)->String {String(name.split(separator:"#",maxSplits:1,omittingEmptySubsequences:false).first ?? "")}
    static func number(_ name:String)->Int {name.split(separator:"#",maxSplits:1).dropFirst().first.flatMap{Int($0)} ?? 0}
    public static func inserting(_ name:String,in frame:SceneFrame)->String {
        let base=baseName(name)
        let next:Int
        if !frame.units.contains(where:{$0.name==name}) {next=number(name)}
        else {next=(frame.units.filter{baseName($0.name)==base}.map{number($0.name)}.max() ?? -1)+1}
        return next==0 ? base:base+"#"+String(next)
    }
}
