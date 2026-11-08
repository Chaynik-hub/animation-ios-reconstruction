import XCTest
@testable import AnimationCore
final class AssetAnimationTests: XCTestCase {
    func testMaximumSpeedAdvancesOnEveryTickStartingAtFirstState() {
        let config = AssetAnimation.Configuration(period: 1, pingPong: true)
        let values = (0...5).compactMap { AssetAnimation.state(in: [0, 4, 9], tick: $0, configuration: config) }
        XCTAssertEqual(values, [0, 4, 9, 4, 0, 4])
    }

    func testWrapAndOriginalForwardReverseLoopWithSparseStates() {
        let wrap = AssetAnimation.Configuration(period: 3, pingPong: false), bounce = AssetAnimation.Configuration(period: 3, pingPong: true)
        XCTAssertEqual([0,2,5,8,11,14].compactMap { AssetAnimation.state(in: [0,4,9], tick: $0, configuration: wrap) }, [0,4,9,0,4,9])
        XCTAssertEqual([0,2,5,8,11,14].compactMap { AssetAnimation.state(in: [0,4,9], tick: $0, configuration: bounce) }, [0,4,9,4,0,4])
    }
    func testInvalidAndSingleStateAndConfigurationRoundTrip() throws {
        let config = AssetAnimation.Configuration(period: 0, pingPong: true, startID: 3, endID: 19)
        XCTAssertEqual(config.period, 3)
        XCTAssertNil(AssetAnimation.state(in: [], tick: 0, configuration: config))
        XCTAssertNil(AssetAnimation.state(in: [1], tick: -1, configuration: config))
        XCTAssertEqual(AssetAnimation.state(in: [7], tick: 1000, configuration: config), 7)
        XCTAssertEqual(try JSONDecoder().decode(AssetAnimation.Configuration.self, from: JSONEncoder().encode(config)), config)
    }
}
