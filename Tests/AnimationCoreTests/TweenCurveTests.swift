import XCTest
@testable import AnimationCore

final class TweenCurveTests: XCTestCase {
    func testAndroidCurveSetAndEndpointBehaviour() {
        XCTAssertEqual(TweenCurve.allCases.count, 11)
        for curve in TweenCurve.allCases {
            XCTAssertEqual(curve.progress(0, strength: 1), 0)
            XCTAssertEqual(curve.progress(1, strength: 1), 1)
            XCTAssertEqual(curve.progress(0.3, strength: 0), 0.3)
        }
        XCTAssertLessThan(TweenCurve.back.progress(0.25, strength: 1), 0)
        XCTAssertGreaterThan(TweenCurve.back.progress(0.75, strength: 1), 1)
        XCTAssertLessThan(TweenCurve.inQuint.progress(0.5, strength: 1), 0.5)
        XCTAssertGreaterThan(TweenCurve.outQuint.progress(0.5, strength: 1), 0.5)
    }
}
