import Foundation
public enum AssetAnimation {
    public struct Configuration: Codable, Equatable {
        public var period: Int
        public var pingPong: Bool
        public var startID: Int?
        public var endID: Int?
        public init(period: Int, pingPong: Bool, startID: Int? = nil, endID: Int? = nil) { self.period = period == 1 ? 1 : max(3, min(53, period)); self.pingPong = pingPong; self.startID = startID; self.endID = endID }
    }
    public static func state(in states: [Int], tick: Int, configuration: Configuration) -> Int? {
        let values = Array(Set(states)).sorted()
        guard !values.isEmpty, tick >= 0 else { return nil }
        let steps = configuration.period == 1 ? tick : (tick + 1) / max(3, min(53, configuration.period))
        if !configuration.pingPong || values.count == 1 { return values[steps % values.count] }
        let span = values.count - 1, phase = steps % (span * 2)
        return values[phase <= span ? phase : span * 2 - phase]
    }
}
