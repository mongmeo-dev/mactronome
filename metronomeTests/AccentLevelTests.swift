import XCTest
@testable import metronome

final class AccentLevelTests: XCTestCase {
    func test_mute_hasZeroGain() {
        XCTAssertEqual(AccentLevel.mute.gain, 0)
    }
    func test_strong_louderThanWeak() {
        XCTAssertGreaterThan(AccentLevel.strong.gain, AccentLevel.weak.gain)
    }
    func test_rawValuesMatchDesign() {
        XCTAssertEqual(AccentLevel.mute.rawValue, 0)
        XCTAssertEqual(AccentLevel.weak.rawValue, 1)
        XCTAssertEqual(AccentLevel.medium.rawValue, 2)
        XCTAssertEqual(AccentLevel.strong.rawValue, 3)
    }
}
